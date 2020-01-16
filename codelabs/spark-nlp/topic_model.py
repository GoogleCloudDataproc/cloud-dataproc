# Copyright 2019 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This code accompanies this codelab: https://codelabs.developers.google.com/codelabs/spark-nlp.
# In this example, we will build a topic model using spark-nlp and Spark ML.
# In order for this code to work properly, a bucket name must be provided.

# Python imports
import sys

# spark-nlp components. Each one is incorporated into our pipeline.
from sparknlp.annotator import Lemmatizer, Stemmer, Tokenizer, Normalizer
from sparknlp.base import DocumentAssembler, Finisher

# A Spark Session is how we interact with Spark SQL to create Dataframes
from pyspark.sql import SparkSession

# These allow us to create a schema for our data
from pyspark.sql.types import StructField, StructType, StringType, LongType

# Spark Pipelines allow us to sequentially add components such as transformers 
from pyspark.ml import Pipeline

# These are components we will incorporate into our pipeline.
from pyspark.ml.feature import StopWordsRemover, CountVectorizer, IDF

# LDA is our model of choice for topic modeling
from pyspark.ml.clustering import LDA

# Some transformers require the usage of other Spark ML functions. We import them here
from pyspark.sql.functions import col, lit, concat, regexp_replace

# This will help catch some PySpark errors
from pyspark.sql.utils import AnalysisException

# Assign bucket where the data lives
try:
  bucket = sys.argv[1]
except IndexError:
  print("Please provide a bucket name")
  sys.exit(1)

# Create a SparkSession under the name "reddit". Viewable via the Spark UI
spark = SparkSession.builder.appName("reddit topic model").getOrCreate()
    
# Create a three column schema consisting of two strings and a long integer
fields = [StructField("title", StringType(), True),
          StructField("body", StringType(), True),
          StructField("created_at", LongType(), True)]
schema = StructType(fields)

# We'll attempt to process every year / month combination below.
years = ['2016', '2017', '2018', '2019']
months = ['01', '02', '03', '04', '05', '06',
          '07', '08', '09', '10', '11', '12']

# This is the subreddit we're working with.
subreddit = "food"

# Create a base dataframe. 
reddit_data = spark.createDataFrame([], schema)
        
# Keep a running list of all files that will be processed
files_read = []

for year in years:
  for month in months:
        
    # In the form of <project-id>.<dataset>.<table>
    gs_uri = f"gs://{bucket}/reddit_posts/{year}/{month}/{subreddit}.csv.gz"
        
    # If the table doesn't exist we will simply continue and not
    # log it into our "tables_read" list
    try:
      reddit_data = (
        spark.read.format('csv')
        .options(codec="org.apache.hadoop.io.compress.GzipCodec")
        .load(gs_uri, schema=schema)
        .union(reddit_data)
      )
            
      files_read.append(gs_uri)

    except AnalysisException:
      continue
        
if len(files_read) == 0:
  print('No files read')
  sys.exit(1)

# Replacing null values with their respective typed-equivalent is usually 
# easier to work with. In this case, we'll replace nulls with empty strings.
# Since some of our data doesn't have a body, we can combine all of the text
# for the titles and bodies so that every row has useful data.

df_train = (
    reddit_data
    # Replace null values with an empty string
    .fillna("") 
    .select(
        # Combine columns
        concat(
            # First column to concatenate. col() is used to specify that we're referencing a column
            col("title"), 
            # Literal character that will be between the concatenated columns.
            lit(" "), 
            # Second column to concatenate.
            col("body")
        # Change the name of the new column    
        ).alias("text") 
    )
    # The text has several tags including [REMOVED] or [DELETED] for redacted content. 
    # We'll replace these with empty strings.
    .select(
        regexp_replace(col("text"), "\[.*?\]", "")
        .alias("text")
    )
)

# Now, we begin assembling our pipeline. Each component here is used to some transformation to the data.
# The Document Assembler takes the raw text data and convert it into a format that can
# be tokenized. It becomes one of spark-nlp native object types, the "Document".
document_assembler = DocumentAssembler().setInputCol("text").setOutputCol("document")

# The Tokenizer takes data that is of the "Document" type and tokenizes it. 
# While slightly more involved than this, this is effectively taking a string and splitting
# it along ths spaces, so each word is its own string. The data then becomes the 
# spark-nlp native type "Token".
tokenizer = Tokenizer().setInputCols(["document"]).setOutputCol("token")

# The Normalizer will group words together based on similar semantic meaning. 
normalizer = Normalizer().setInputCols(["token"]).setOutputCol("normalizer")

# The Stemmer takes objects of class "Token" and converts the words into their
# root meaning. For instance, the words "cars", "cars'" and "car's" would all be replaced
# with the word "car".
stemmer = Stemmer().setInputCols(["normalizer"]).setOutputCol("stem")

# The Finisher signals to spark-nlp allows us to access the data outside of spark-nlp
# components. For instance, we can now feed the data into components from Spark MLlib. 
finisher = Finisher().setInputCols(["stem"]).setOutputCols(["to_spark"]).setValueSplitSymbol(" ")

# Stopwords are common words that generally don't add much detail to the meaning
# of a body of text. In English, these are mostly "articles" such as the words "the"
# and "of".
stopword_remover = StopWordsRemover(inputCol="to_spark", outputCol="filtered")

# Here we implement TF-IDF as an input to our LDA model. CountVectorizer (TF) keeps track
# of the vocabulary that's being created so we can map our topics back to their
# corresponding words.
# TF (term frequency) creates a matrix that counts how many times each word in the
# vocabulary appears in each body of text. This then gives each word a weight based
# on it's frequency.
tf = CountVectorizer(inputCol="filtered", outputCol="raw_features")

# Here we implement the IDF portion. IDF (Inverse document frequency) reduces 
# the weights of commonly-appearing words. 
idf = IDF(inputCol="raw_features", outputCol="features")

# LDA creates a statistical representation of how frequently words appear 
# together in order to create "topics" or groups of commonly appearing words.
# In this case, we'll create 5 topics.
lda = LDA(k=5)

# We add all of the transformers into a Pipeline object. Each transformer
# will execute in the ordered provided to the "stages" parameter
pipeline = Pipeline(
    stages = [
        document_assembler,
        tokenizer,
        normalizer,        
        stemmer,
        finisher,
        stopword_remover,
        tf,
        idf,
        lda
    ]
)

# We fit the data to the model. 
model = pipeline.fit(df_train)

# Now that we have completed a pipeline, we want to output the topics as human-readable.
# To do this, we need to grab the vocabulary generated from our pipeline, grab the topic
# model and do the appropriate mapping.  The output from each individual component lives 
# in the model object. We can access them by referring to them by their position in 
# the pipeline via model.stages[<ind>]

# Let's create a reference our vocabulary.
vocab = model.stages[-3].vocabulary

# Next, let's grab the topics generated by our LDA model via describeTopics(). Using collect(),
# we load the output into a Python array.
raw_topics = model.stages[-1].describeTopics(maxTermsPerTopic=5).collect()

# Lastly, let's get the indices of the vocabulary terms from our topics
topic_inds = [ind.termIndices for ind in raw_topics]

# The indices we just grab directly map to the term at position <ind> from our vocabulary. 
# Using the below code, we can generate the mappings from our topic indicies to our vocabulary.
topics = []
for topic in topic_inds:
  _topic = []
  for ind in topic:
    _topic.append(vocab[ind])
  topics.append(_topic)

# Let's see our topics!
for i, topic in enumerate(topics, start=1):
    print(f"topic {i}: {topic}")
