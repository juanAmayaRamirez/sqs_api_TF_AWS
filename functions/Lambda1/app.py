import os
import json

GREETING=os.environ['GREETING']

def lambda_handler(event, context):
    print(json.dumps(event))
    print(context)
    return f"{GREETING} from Lambda!"