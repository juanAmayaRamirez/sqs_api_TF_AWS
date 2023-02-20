import os

GREETING=os.environ['GREETING']

def lambda_handler(event, context):
    return f"{GREETING} from Lambda!"