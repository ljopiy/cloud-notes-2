# 1. Сборка Docker образа
docker build -t cr.yandex/crpdq4k6hq5t9a5tjlu9/cloud-notes-backend:latest -f backend/Dockerfile.prod ./backend

# 2. Push в Container Registry
docker push cr.yandex/crpdq4k6hq5t9a5tjlu9/cloud-notes-backend:latest

# 3. Обновление instance group через YC CLI
yc compute instance-group update \
  --name cloud-notes-backend-ig \
  --template-labels version=$(date +%Y%m%d-%H%M%S)

# 4. Проверка health checks
echo "Checking load balancer health..."
for i in {1..30}; do
  STATUS=$(yc alb backend-group get cloud-notes-backend-bg --format json | jq -r '.http_backends[0].status')
  echo "Attempt $i: Backend status: $STATUS"
  
  if [ "$STATUS" = "ACTIVE" ]; then
    echo "✅ All backends are healthy!"
    break
  fi
  
  sleep 5
done

# 5. Получение IP балансировщика
ALB_IP=$(yc alb load-balancer get cloud-notes-alb --format json | jq -r '.listeners[0].endpoints[0].address.external_ipv4_address.address')
echo "��� Load Balancer IP: $ALB_IP"
echo "��� Application URL: http://$ALB_IP"
