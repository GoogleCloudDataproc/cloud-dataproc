# Workshop for Machine Learning and NLP on Social Media Data at Scale

This workshop will take you through processing Social Media data at scale from start to finish. We'll use a dataset consisting of all Reddit posts since 2016 stored in BigQuery. 

First, you will load the Reddit data from [BigQuery](https://cloud.google.com/bigquery/) into PySpark using [Cloud Dataproc](https://cloud.google.com/dataproc/):
[PySpark for Preprocessing BigQuery Data](bit.ly/pyspark-bigquery)

Next, you will use the open source library [spark-nlp](https://nlp.johnsnowlabs.com/) to create a [topic model](https://www.kdnuggets.com/2016/07/text-mining-101-topic-modeling.html) using [Latent Dirichlet Allocation (LDA)](https://medium.com/@lettier/how-does-lda-work-ill-explain-using-emoji-108abf40fa7d) to learn about trends in your data: [PySpark for Natural Language Processing](bit.ly/spark-nlp)

Lastly, you'll learn to use [Cloud AutoML](https://cloud.google.com/automl/) and [Natural Language APIs](https://cloud.google.com/natural-language/) to derive more insights from your data : [Google Cloud AutoML and Natural Language APIs](bit.ly/social-media-nlp)
