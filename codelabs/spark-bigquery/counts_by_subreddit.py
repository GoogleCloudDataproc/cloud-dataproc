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

# This script accompanies this codelab: https://codelabs.developers.google.com/codelabs/pyspark-bigquery/.
# This is a script for viewing counts of all subreddits for a given set of years and month
# This data comes from BigQuery via the dataset "fh-bigquery.reddit_comments"

# These allow us to create a schema for our data
from pyspark.sql.types import StructField, StructType, StringType, LongType

# A Spark Session is how we interact with Spark SQL to create Dataframes
from pyspark.sql import SparkSession

# This will help catch some PySpark errors
from py4j.protocol import Py4JJavaError

# Create a SparkSession under the name "reddit". Viewable via the Spark UI
spark = SparkSession.builder.appName("reddit").getOrCreate()

# Create a two column schema consisting of a string and a long integer
fields = [StructField("subreddit", StringType(), True),
          StructField("count", LongType(), True)]
schema = StructType(fields)

# Create an empty DataFrame. We will continuously union our output with this
subreddit_counts = spark.createDataFrame([], schema)

# Establish a set of years and months to iterate over
years = ['2016', '2017', '2018', '2019']
months = ['01', '02', '03', '04', '05', '06',
          '07', '08', '09', '10', '11', '12']

# Keep track of all tables accessed via the job
tables_read = []
for year in years:
  for month in months:
    
    # In the form of <project-id>.<dataset>.<table>
    table = f"fh-bigquery.reddit_posts.{year}_{month}"
        
    # If the table doesn't exist we will simply continue and not
    # log it into our "tables_read" list
    try:
      table_df = spark.read.format('bigquery').option('table', table).load()
      tables_read.append(table)
    except Py4JJavaError:
      continue
        
    # We perform a group-by on subreddit, aggregating by the count and then
    # unioning the output to our base dataframe
    subreddit_counts = (
        table_df
        .groupBy("subreddit")
        .count()
        .union(subreddit_counts)
    )
        
print("The following list of tables will be accounted for in our analysis:")
for table in tables_read:
  print(table)

# From our base table, we perform a group-by, summing over the counts.
# We then rename the column and sort in descending order both for readability.
# show() will collect the table into memory output the table to std out.
(
    subreddit_counts
    .groupBy("subreddit")
    .sum("count")
    .withColumnRenamed("sum(count)", "count")
    .sort("count", ascending=False)
    .show()
)
