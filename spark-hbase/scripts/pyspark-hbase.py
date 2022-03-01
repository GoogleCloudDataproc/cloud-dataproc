from pyspark.sql import SparkSession

# Initialize Spark Session
spark = SparkSession \
  .builder \
  .master('yarn') \
  .appName('spark-hbase-tutorial') \
  .getOrCreate()

data_source_format = ''

# Create some test data
df = spark.createDataFrame(
    [
        ("key1", "foo"),
        ("key2", "bar"),
    ],
    ["key", "name"]
)

# Define the schema for catalog
catalog = ''.join("""{
    "table":{"namespace":"default", "name":"my_table"},
    "rowkey":"key",
    "columns":{
        "key":{"cf":"rowkey", "col":"key", "type":"string"},
        "name":{"cf":"cf", "col":"name", "type":"string"}
    }
}""".split())

# Write to HBase
df.write.format('org.apache.hadoop.hbase.spark').options(catalog=catalog).option("hbase.spark.use.hbasecontext", "false").mode("overwrite").save()

# Read from HBase
result = spark.read.format('org.apache.hadoop.hbase.spark').options(catalog=catalog).option("hbase.spark.use.hbasecontext", "false").load()
result.show()