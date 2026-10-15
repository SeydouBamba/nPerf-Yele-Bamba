package results

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"

	"github.com/librespeed/speedtest-go/database"
	log "github.com/sirupsen/logrus"
)

func jsonResponse(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(data); err != nil {
		log.Errorf("dashboard json encode error: %s", err)
	}
}

func mongoRequired(w http.ResponseWriter) bool {
	if database.MongoDB == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusServiceUnavailable)
		w.Write([]byte(`{"error":"Dashboard requires database_type=mongodb"}`))
		return false
	}
	return true
}

// DashboardQoeUpdate rattache une note QoE à une mesure déjà transmise.
//
// POST /api/dashboard/qoe  {"id":"<uuid>","qoeRating":1-5,"qoeSatisfaction":"..."}
//
// Nécessaire depuis ISS-09 : la mesure part dès la fin du test — donc avant que
// l'utilisateur n'ait répondu au questionnaire — et la note est rattachée après
// coup par cet appel. Idempotent : une seconde réponse écrase la précédente.
func DashboardQoeUpdate(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}

	// Corps court (identifiant + note) : on le borne pour éviter tout envoi abusif.
	var body struct {
		ID              string `json:"id"`
		QoeRating       int    `json:"qoeRating"`
		QoeSatisfaction string `json:"qoeSatisfaction"`
		QoeUsage        string `json:"qoeUsage"`
	}
	if err := json.NewDecoder(io.LimitReader(r.Body, 4<<10)).Decode(&body); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error":"invalid json body"}`))
		return
	}
	if body.ID == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error":"missing id"}`))
		return
	}
	// Une note hors 1-5 n'est pas exploitable : mieux vaut un refus explicite
	// qu'une note à 0 qui fausserait les moyennes du dashboard.
	if body.QoeRating < 1 || body.QoeRating > 5 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(`{"error":"qoeRating must be between 1 and 5"}`))
		return
	}

	found, err := database.MongoDB.UpdateQoe(body.ID, body.QoeRating, body.QoeSatisfaction)
	if err != nil {
		log.Errorf("DashboardQoeUpdate error: %s", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(`{"error":"update failed"}`))
		return
	}
	if !found {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(`{"error":"measurement not found"}`))
		return
	}

	jsonResponse(w, map[string]interface{}{
		"ok":        true,
		"id":        body.ID,
		"qoeRating": body.QoeRating,
	})
}

// DashboardSummary returns high-level KPIs.
// GET /api/dashboard/summary
func DashboardSummary(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	stats, err := database.MongoDB.FetchSummary()
	if err != nil {
		log.Errorf("DashboardSummary error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, stats)
}

// DashboardResults returns paginated test results with optional filters.
// GET /api/dashboard/results?page=1&limit=20&operator=&network=&from=YYYY-MM-DD&to=YYYY-MM-DD
func DashboardResults(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit < 1 || limit > 100 {
		limit = 20
	}
	operator := r.URL.Query().Get("operator")
	network := r.URL.Query().Get("network")
	from := r.URL.Query().Get("from")
	to := r.URL.Query().Get("to")

	page2, err := database.MongoDB.FetchResults(page, limit, operator, network, from, to)
	if err != nil {
		log.Errorf("DashboardResults error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, page2)
}

// DashboardOperators returns per-operator aggregated stats.
// GET /api/dashboard/operators
func DashboardOperators(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	stats, err := database.MongoDB.FetchOperatorStats()
	if err != nil {
		log.Errorf("DashboardOperators error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, stats)
}

// DashboardMap returns geolocated test points for the map.
// GET /api/dashboard/map
func DashboardMap(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	points, err := database.MongoDB.FetchMapPoints()
	if err != nil {
		log.Errorf("DashboardMap error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, points)
}

// DashboardTimeline returns daily test counts and average download speed.
// GET /api/dashboard/timeline?days=30
func DashboardTimeline(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	days, _ := strconv.Atoi(r.URL.Query().Get("days"))
	if days < 1 || days > 365 {
		days = 30
	}
	points, err := database.MongoDB.FetchTimeline(days)
	if err != nil {
		log.Errorf("DashboardTimeline error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, points)
}

// DashboardHeatmap returns GPS points with quality intensity for heatmap rendering.
// GET /api/dashboard/heatmap
func DashboardHeatmap(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	points, err := database.MongoDB.FetchHeatmap()
	if err != nil {
		log.Errorf("DashboardHeatmap error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, points)
}

// DashboardAdvancedStats returns percentile stats per operator.
// GET /api/dashboard/stats/advanced
func DashboardAdvancedStats(w http.ResponseWriter, r *http.Request) {
	if !mongoRequired(w) {
		return
	}
	stats, err := database.MongoDB.FetchAdvancedStats()
	if err != nil {
		log.Errorf("DashboardAdvancedStats error: %s", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	jsonResponse(w, stats)
}
