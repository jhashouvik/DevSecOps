FROM node:16 as builder 
WORKDIR /usr/src
COPY package.json ./
RUN npm install
COPY ./src ./src
COPY ./public ./public
RUN rm -rf node_modules
RUN npm ci --only=production

# Final stage
FROM alpine:latest as production
RUN apk --no-cache add nodejs ca-certificates
WORKDIR /root/
EXPOSE 3000
COPY --from=builder /usr/src ./
CMD ["node","src/index.js"]
