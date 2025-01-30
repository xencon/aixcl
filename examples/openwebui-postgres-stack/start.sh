echo "Creating admin user..."
curl \
  -X POST "http://localhost:8080/api/v1/auths/signup" \
  -H "accept: application/json" \
  -H "Content-Type: application/json" \
  -d "{ \"email\": \"${ADMIN_USER_EMAIL}\", \"password\": \"${ADMIN_USER_PASSWORD}\", \"name\": \"Admin\" }"