import os
import json
import boto3

def handler(event, context):
    print("Received event:", json.dumps(event))

    eb = boto3.client('events')

    if event.get('source') == 'game.match':
        detail = event.get('detail', {})
        player_id = detail.get('playerId')
        reward = detail.get('rewardAmount', 0)

        print(f"Distributing reward {reward} to player {player_id}")

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processed'})
    }
