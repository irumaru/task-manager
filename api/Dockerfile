FROM golang:1.26.2 AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

FROM alpine:3.23.4

# サーバー側ではタイムゾーンをUTCに設定
# クライアントアプリ側ではユーザーのローカルタイムゾーンに変換する
RUN apk add --no-cache tzdata
ENV TZ=UTC

COPY --from=builder /server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
