package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"time"
)

const (
	pipelineScript = "./pipeline.sh"
	timeout        = 30 * time.Second
)

type Response struct {
	Success bool        `json:"success"`
	Results interface{} `json:"results,omitempty"`
	Error   string      `json:"error,omitempty"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/health", handleHealth)
	http.HandleFunc("/solve", handleSolve)
	http.HandleFunc("/api/gecode", handleSolve)

	log.Printf("🚀 Gecode CSP API starting on port %s", port)
	log.Printf("   POST /api/gecode  - Solve CSP problem")
	log.Printf("   GET  /health      - Health check")

	if err := http.ListenAndServe(":"+port, enableCORS(http.DefaultServeMux)); err != nil {
		log.Fatal(err)
	}
}

func handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "ok",
		"service":   "Gecode CSP API",
		"timestamp": time.Now().Unix(),
	})
}

func handleSolve(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		sendError(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		sendError(w, "Failed to read request body", http.StatusBadRequest)
		return
	}
	defer r.Body.Close()

	// Validar que sea JSON válido
	var raw interface{}
	if err := json.Unmarshal(body, &raw); err != nil {
		sendError(w, fmt.Sprintf("Invalid JSON: %v", err), http.StatusBadRequest)
		return
	}

	// Escribir a archivo temporal
	tmpFile, err := os.CreateTemp("", "gecode-*.json")
	if err != nil {
		sendError(w, "Failed to create temp file", http.StatusInternalServerError)
		return
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	if _, err := tmpFile.Write(body); err != nil {
		tmpFile.Close()
		sendError(w, "Failed to write temp file", http.StatusInternalServerError)
		return
	}
	tmpFile.Close()

	// Ejecutar pipeline con timeout
	result, err := runPipeline(tmpPath)
	if err != nil {
		sendError(w, fmt.Sprintf("Pipeline error: %v", err), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(Response{
		Success: true,
		Results: result,
	})
}

func runPipeline(inputPath string) (string, error) {
	cmd := exec.Command("bash", pipelineScript, inputPath)

	done := make(chan error, 1)
	var output []byte
	var cmdErr error

	go func() {
		output, cmdErr = cmd.CombinedOutput()
		done <- cmdErr
	}()

	select {
	case err := <-done:
		if err != nil {
			return "", fmt.Errorf("%v — %s", err, string(output))
		}
		return string(output), nil
	case <-time.After(timeout):
		cmd.Process.Kill()
		return "", fmt.Errorf("execution timeout after %v", timeout)
	}
}

func sendError(w http.ResponseWriter, message string, statusCode int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(Response{
		Success: false,
		Error:   message,
	})
}

func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}
