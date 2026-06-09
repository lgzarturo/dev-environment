#!/bin/bash
# diagnose-sns-sqs.sh

SNS_TOPIC_ARN="arn:aws:sns:us-east-1:623842294996:reservation-cancelled-development"
SQS_QUEUE_URL="https://sqs.us-east-1.amazonaws.com/623842294996/loyalty-cancel-points-development"
SQS_QUEUE_ARN="arn:aws:sqs:us-east-1:623842294996:loyalty-cancel-points-development"

echo "=== Verificando suscripciones del tema ==="
aws sns list-subscriptions-by-topic --topic-arn $SNS_TOPIC_ARN

echo -e "\n=== Verificando política de la cola SQS ==="
aws sqs get-queue-attributes --queue-url $SQS_QUEUE_URL --attribute-names Policy

echo -e "\n=== Verificando atributos de la cola SQS ==="
aws sqs get-queue-attributes --queue-url $SQS_QUEUE_URL --attribute-names All

echo -e "\n=== Enviando mensaje de prueba al SNS ==="
MESSAGE_ID=$(aws sns publish \
  --topic-arn $SNS_TOPIC_ARN \
  --message "{\"type\":\"CANCEL\",\"code\":\"TEST_DIAG_$(date +%s)\",\"uuid\":\"$(uuidgen)\",\"status\":\"CANCELLED\",\"account\":\"test_account\"}" \
  --message-attributes "{\"event_type\":{\"DataType\":\"String\",\"StringValue\":\"CANCELLATION\"}}" \
  --output text --query 'MessageId')

echo "Mensaje enviado con ID: $MESSAGE_ID"
echo "Esperando 10 segundos para que el mensaje se procese..."
sleep 10

echo -e "\n=== Verificando mensajes en la cola SQS ==="
aws sqs receive-message --queue-url $SQS_QUEUE_URL --max-number-of-messages 10 --wait-time-seconds 5

echo -e "\n=== Verificando métricas de SNS (últimos 5 minutos) ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/SNS \
  --metric-name NumberOfNotificationsDelivered \
  --dimensions Name=TopicName,Value=$(echo $SNS_TOPIC_ARN | cut -d':' -f6) \
  --start-time $(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --period 300 \
  --statistics Sum

echo -e "\n=== Verificando métricas de SQS (últimos 5 minutos) ==="
aws cloudwatch get-metric-statistics \
  --namespace AWS/SQS \
  --metric-name NumberOfMessagesReceived \
  --dimensions Name=QueueName,Value=$(echo $SQS_QUEUE_URL | cut -d'/' -f5) \
  --start-time $(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ") \
  --end-time $(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --period 300 \
  --statistics Sum

echo -e "\n=== Diagnóstico completo ==="
