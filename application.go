package main

import (
	"expvar"
	"log"
	"net/http"
)

var (
	redirects = expvar.NewInt("redirects")
)

func redirect(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "https://welt.de", http.StatusMovedPermanently)
	redirects.Add(1)
	log.Printf("Redirected...")
}

func health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
}

func main() {
	http.HandleFunc("/redirecter/", redirect)
	http.HandleFunc("/redirecter/health", health)

	log.Fatal(http.ListenAndServe(":9090", nil))
}
