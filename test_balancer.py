import requests
import time

ALB_IP = "your-alb-ip"  # Заменить на реальный IP

def test_load_balancing():
    print("🔍 Testing load balancer...")
    
    # Отправляем 10 запросов, чтобы увидеть балансировку
    for i in range(10):
        try:
            response = requests.get(f"http://{ALB_IP}/health", timeout=2)
            server = response.headers.get('X-Backend-Server', 'unknown')
            print(f"Request {i+1}: Status {response.status_code}, Server: {server}")
        except Exception as e:
            print(f"Request {i+1}: Error - {e}")
        
        time.sleep(0.5)
    
    # Тестирование отказоустойчивости
    print("\n🔧 Testing failover...")
    
    # Получаем список инстансов
    instances = ["backend1_ip", "backend2_ip"]  # Заменить на реальные IP
    
    print("Stopping one backend instance...")
    # Останавливаем один инстанс (в реальности через YC CLI)
    
    # Продолжаем отправлять запросы
    for i in range(5):
        try:
            response = requests.get(f"http://{ALB_IP}/health", timeout=2)
            print(f"After failover {i+1}: Status {response.status_code}")
        except Exception as e:
            print(f"After failover {i+1}: Error - {e}")
        
        time.sleep(1)

if __name__ == "__main__":
    test_load_balancing()

'''husainova@LAPTOP-182RJI1P:~/Cloud-Notes/terraform$ yc iam access-key create --service-account-name shchavr
access_key:
  id: ajeba18q5o401q3s0ci6
  service_account_id: ajepneleb5djp2m51m3u
  created_at: "2025-12-15T15:50:44.663052227Z"
  key_id: YCAJEztIZF8VCEN99FJ0h_0u5
secret: YCP4kSDk7xGsiarj702fNy90RmYyTWIXUIIwApn8'''