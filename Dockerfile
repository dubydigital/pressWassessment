FROM node:22-alpine

WORKDIR /app

# Copy package files first so Docker can cache npm install
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy application source
COPY . .

# Document the port used by Fastify
EXPOSE 3000

# Start the API
CMD ["npm", "start"]
