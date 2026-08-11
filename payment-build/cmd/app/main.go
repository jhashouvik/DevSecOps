package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/go-sql-driver/mysql"
	"github.com/gorilla/mux"
	"github.com/nitishfy/REST-API/internal/config"
	"github.com/nitishfy/REST-API/internal/handlers"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	API_PATH = "/apis/v1/books"
)

func main() {
	dbHost := os.Getenv("DB_HOST")
	if dbHost == "" {
		dbHost = "localhost:3306"
	}

	dbName := os.Getenv("DB_NAME")
	if dbName == "" {
		dbName = "library"
	}

	dbUser := os.Getenv("DB_USER")
	if dbUser == "" {
		dbUser = "root"
	}

	dbPass := os.Getenv("DB_PASSWORD")
	if dbPass == "" {
		dbPass = "my-default-password"
	}

	apiPath := os.Getenv("API_PATH")
	if apiPath == "" {
		apiPath = API_PATH
	}

	router := mux.NewRouter()

	// Prometheus metrics
	router.Handle("/metrics", promhttp.Handler())

	// Liveness probe
	router.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "Payment is Live Now-canary")
	}).Methods("GET")

// Readiness probe
    router.HandleFunc("/readyz", func(w http.ResponseWriter, r *http.Request) {

	    cfg := config.Config{
		    User:     dbUser,
		    Password: dbPass,
		    Addr:     dbHost,
		    DBName:   dbName,
	    }

	    db := cfg.OpenConnection()
	    defer cfg.CloseConnection(db)

	    if err := db.Ping(); err != nil {
		    http.Error(w, "database unavailable", http.StatusServiceUnavailable)
		    return
	    }

	    w.WriteHeader(http.StatusOK)
	    fmt.Fprint(w, "Payment is Ready Now-canary")
    }).Methods("GET")

	ch := handlers.ConfigHandler{
		Config: &config.Config{
			User:     dbUser,
			Password: dbPass,
			Addr:     dbHost,
			DBName:   dbName,
		},
	}

	router.HandleFunc(apiPath, ch.GetBooks).Methods("GET")
	router.HandleFunc(apiPath+"/{id}", ch.GetBookByID).Methods("GET")
	router.HandleFunc(apiPath, ch.PostBook).Methods("POST")
	router.HandleFunc(apiPath+"/{id}", ch.UpdateBook).Methods("PUT")
	router.HandleFunc(apiPath, ch.DeleteBooks).Methods("DELETE")
	router.HandleFunc(apiPath+"/{id}", ch.DeleteBookByID).Methods("DELETE")

	log.Println("Server starting on :8081")

	if err := http.ListenAndServe(":8081", router); err != nil {
		log.Fatalf("error while listening: %v", err)
	}
}