FROM node:24-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM node:24-alpine AS runner

ENV NODE_ENV=production
ENV PORT=3000
WORKDIR /app

COPY --from=builder /app/package*.json ./
RUN npm ci && npm cache clean --force
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/public ./public

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://127.0.0.1:3000/ || exit 1

CMD ["npm", "run", "start", "--", "--hostname", "0.0.0.0"]
