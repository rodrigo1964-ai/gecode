FROM ubuntu:24.04

# Instalar dependencias
RUN apt-get update && apt-get install -y \
    golang \
    libgecode-dev \
    libgecode49t64 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copiar fuentes Go
COPY go.mod main.go ./

# Compilar servidor Go
RUN go build -o app main.go

# Copiar el resto del proyecto
COPY bin/ ./bin/
COPY pipeline.sh ./

EXPOSE 10000

CMD ["./app"]
