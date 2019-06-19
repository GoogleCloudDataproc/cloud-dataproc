from pyspark.sql import SparkSession
import time

spark = SparkSession.builder.appName("reddit").getOrCreate()

table = "fh-bigquery.reddit_posts.2019_01"
df = spark.read.format('bigquery').option('table', table).load()
subreddit = 'worldpolitics'
bucket_name = "bm_reddit"
path = "tmp" + str(time.time())
tmp_output_path = "gs://" + bucket_name + "/" + path + "/" + "2019" + "/" + "01"

subreddit_timestamps = (
    df
    .select("title", "selftext", "created_utc")
    .where(df.subreddit == subreddit)
)

print(subreddit_timestamps.take(5))
(
    subreddit_timestamps
    # Data can get written out to multiple files / partition. 
    # This ensures it will only write to 1.
    .coalesce(1) 
    .write
    # Gzip the output file
    .options(codec="org.apache.hadoop.io.compress.GzipCodec")
    # Write out to csv
    .csv(tmp_output_path)
)
print(tmp_output_path)