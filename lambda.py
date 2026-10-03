import json
import boto3
import io
from io import StringIO
import pandas as pd
import ML_OP.transformations as tp

s3_client = boto3.client('s3')
target_bucket_name = "mlopslab2"

def lambda_handler(event, context):
    
    try:
        
        s3_bucket_name = event["Records"][0]["s3"]["bucket"]["name"]
        s3_file_name = event["Records"][0]["s3"]["object"]["key"]

        source_object = s3_client.get_object(Bucket=s3_bucket_name, Key=s3_file_name)
        body = source_object['Body']
        csv_string = body.read().decode('utf-8')
        dataframe = pd.read_csv(StringIO(csv_string))
        
        transformedDF = tp.transformation_pipeline(dataframe)
        dataframe = transformedDF
        
        with io.StringIO() as csv_buffer:
            dataframe.to_csv(csv_buffer, index=False)
            response = s3_client.put_object(
                Bucket=target_bucket_name, Key="data.csv", Body=csv_buffer.getvalue()
            )

        
        print(dataframe.head(3))
        
    except Exception as err:
        print(err)
        
    return {
        'statusCode': 200,
        'body': json.dumps('Success')
    }
