package hbase;

import org.apache.hadoop.hbase.spark.datasources.HBaseTableCatalog;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;

import java.io.Serializable;
import java.util.Arrays;
import java.util.HashMap;
import java.util.Map;

public class SparkHBaseMain {
    public static class SampleData implements Serializable {
        private String key;
        private String name;


        public SampleData(String key, String name) {
            this.key = key;
            this.name = name;
        }

        public SampleData() {
        }

        public String getName() {
            return name;
        }

        public void setName(String name) {
            this.name = name;
        }

        public String getKey() {
            return key;
        }

        public void setKey(String key) {
            this.key = key;
        }
    }
    public static void main(String[] args) {
        // Init SparkSession
        SparkSession spark = SparkSession
                .builder()
                .master("yarn")
                .appName("spark-hbase-tutorial")
                .getOrCreate();

        // Data Schema
        String catalog = "{"+"\"table\":{\"namespace\":\"default\", \"name\":\"my_table\"}," +
                "\"rowkey\":\"key\"," +
                "\"columns\":{" +
                "\"key\":{\"cf\":\"rowkey\", \"col\":\"key\", \"type\":\"string\"}," +
                "\"name\":{\"cf\":\"cf\", \"col\":\"name\", \"type\":\"string\"}" +
                "}" +
                "}";

        Map<String, String> optionsMap = new HashMap<String, String>();
        optionsMap.put(HBaseTableCatalog.tableCatalog(), catalog);

        Dataset<Row> ds= spark.createDataFrame(Arrays.asList(
                new SampleData("key1", "foo"),
                new SampleData("key2", "bar")), SampleData.class);

        // Write to HBase
        ds.write()
                .format("org.apache.hadoop.hbase.spark")
                .options(optionsMap)
                .option("hbase.spark.use.hbasecontext", "false")
                .mode("overwrite")
                .save();

        // Read from HBase
        Dataset dataset = spark.read()
                .format("org.apache.hadoop.hbase.spark")
                .options(optionsMap)
                .option("hbase.spark.use.hbasecontext", "false")
                .load();
        dataset.show();
    }
}
