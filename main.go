package main

import (
	"expvar"
	"log"
	"net/http"
)

var (
	redirects = expvar.NewInt("redirects")
)

func handler(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, "https://welt.de", http.StatusMovedPermanently)
	redirects.Add(1)
	log.Printf("Redirected...")
}

func main() {
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(":9090", nil))
}
