package main

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"

	"github.com/knadh/listmonk/models"
	"github.com/labstack/echo/v4"
	"github.com/lib/pq"
)

// handleGetRegions returns the list of French regions available in the data
func (a *App) handleGetRegions(c echo.Context) error {
	var regions []models.DepartementRegion

	query := `SELECT DISTINCT region_nom, region_code 
              FROM departement_region_mapping 
              ORDER BY region_nom`

	if err := a.db.Select(&regions, query); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	return c.JSON(http.StatusOK, okResp{regions})
}

// handleGetDepartements returns the list of departments, optionally filtered by region
func (a *App) handleGetDepartements(c echo.Context) error {
	regionNom := c.QueryParam("region")

	var departements []models.DepartementRegion
	var query string
	var args []interface{}

	if regionNom != "" {
		query = `SELECT departement_numero, departement_nom, region_nom, region_code 
                 FROM departement_region_mapping 
                 WHERE region_nom = $1 
                 ORDER BY departement_nom`
		args = append(args, regionNom)
	} else {
		query = `SELECT departement_numero, departement_nom, region_nom, region_code 
                 FROM departement_region_mapping 
                 ORDER BY departement_nom`
	}

	if err := a.db.Select(&departements, query, args...); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	return c.JSON(http.StatusOK, okResp{departements})
}

// handleGetCommunes returns the list of available communes
func (a *App) handleGetCommunes(c echo.Context) error {
	departementNumero := c.QueryParam("departement")
	limit := c.QueryParam("limit")
	search := c.QueryParam("search")

	var communes []models.CommuneInfo

	query := `SELECT nom_commune, code_insee, population_commune, departement_numero, COUNT(*) as count
              FROM subscribers 
              WHERE nom_commune IS NOT NULL AND nom_commune != ''`
	var args []interface{}
	argIndex := 1

	if departementNumero != "" {
		query += fmt.Sprintf(" AND departement_numero = $%d", argIndex)
		args = append(args, departementNumero)
		argIndex++
	}

	if search != "" {
		query += fmt.Sprintf(" AND nom_commune ILIKE $%d", argIndex)
		args = append(args, "%"+search+"%")
		argIndex++
	}

	query += " GROUP BY nom_commune, code_insee, population_commune, departement_numero ORDER BY nom_commune"

	if limit != "" {
		if limitInt, err := strconv.Atoi(limit); err == nil && limitInt > 0 {
			query += fmt.Sprintf(" LIMIT %d", limitInt)
		}
	}

	if err := a.db.Select(&communes, query, args...); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	return c.JSON(http.StatusOK, okResp{communes})
}

// handleGetCSPs returns the list of available socio-professional categories
func (a *App) handleGetCSPs(c echo.Context) error {
	var csps []models.CSPInfo

	query := `SELECT csp, COUNT(*) as count 
              FROM subscribers 
              WHERE csp IS NOT NULL AND csp != '' 
              GROUP BY csp 
              ORDER BY count DESC, csp`

	if err := a.db.Select(&csps, query); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	return c.JSON(http.StatusOK, okResp{csps})
}

// handleGeoQuery executes a geographic segmentation query
func (a *App) handleGeoQuery(c echo.Context) error {
	var params models.GeoQueryParams
	if err := c.Bind(&params); err != nil {
		return echo.NewHTTPError(http.StatusBadRequest, 
			a.i18n.T("globals.messages.invalidData"))
	}

	// Build SQL query dynamically
	query := `SELECT COUNT(*) FROM subscribers s`
	var joinClause string
	var conditions []string
	var args []interface{}
	argIndex := 1

	// Join with mapping table for region filters
	if len(params.Regions) > 0 {
		joinClause = " LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero"
		conditions = append(conditions, fmt.Sprintf("drm.region_nom = ANY($%d)", argIndex))
		args = append(args, pq.Array(params.Regions))
		argIndex++
	}

	// Department filters
	if len(params.Departements) > 0 {
		conditions = append(conditions, fmt.Sprintf("s.departement_numero = ANY($%d)", argIndex))
		args = append(args, pq.Array(params.Departements))
		argIndex++
	}

	// Commune filters
	if len(params.Communes) > 0 {
		conditions = append(conditions, fmt.Sprintf("s.nom_commune = ANY($%d)", argIndex))
		args = append(args, pq.Array(params.Communes))
		argIndex++
	}

	// INSEE code filters
	if len(params.CodesINSEE) > 0 {
		conditions = append(conditions, fmt.Sprintf("s.code_insee = ANY($%d)", argIndex))
		args = append(args, pq.Array(params.CodesINSEE))
		argIndex++
	}

	// Population filters
	if params.UsePopulation {
		if params.PopulationMin != nil {
			conditions = append(conditions, fmt.Sprintf("s.population_commune >= $%d", argIndex))
			args = append(args, *params.PopulationMin)
			argIndex++
		}

		if params.PopulationMax != nil {
			conditions = append(conditions, fmt.Sprintf("s.population_commune <= $%d", argIndex))
			args = append(args, *params.PopulationMax)
			argIndex++
		}
	}

	// CSP filters
	if len(params.CSPs) > 0 {
		conditions = append(conditions, fmt.Sprintf("s.csp = ANY($%d)", argIndex))
		args = append(args, pq.Array(params.CSPs))
		argIndex++
	}

	// Birth date filters
	if params.DateNaissanceMin != nil {
		conditions = append(conditions, fmt.Sprintf("s.date_naissance >= $%d", argIndex))
		args = append(args, *params.DateNaissanceMin)
		argIndex++
	}

	if params.DateNaissanceMax != nil {
		conditions = append(conditions, fmt.Sprintf("s.date_naissance <= $%d", argIndex))
		args = append(args, *params.DateNaissanceMax)
		argIndex++
	}

	// Build final query
	finalQuery := query + joinClause

	// Add conditions
	if len(conditions) > 0 {
		finalQuery += " WHERE " + strings.Join(conditions, " AND ")
		finalQuery += " AND s.status = 'enabled'"
	} else {
		finalQuery += " WHERE s.status = 'enabled'"
	}

	var count int
	if err := a.db.Get(&count, finalQuery, args...); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			fmt.Sprintf("Error executing query: %v", err))
	}

	return c.JSON(http.StatusOK, okResp{map[string]interface{}{
		"count":  count,
		"query":  finalQuery,
		"params": params,
	}})
}

// handleGetGeoStats returns global geographic statistics
func (a *App) handleGetGeoStats(c echo.Context) error {
	var stats models.GeoStats

	// Global statistics
	if err := a.db.Get(&stats.TotalSubscribers,
		"SELECT COUNT(*) FROM subscribers WHERE status = 'enabled'"); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	// Statistics by region
	var regionStats []struct {
		Region string `db:"region_nom"`
		Count  int    `db:"count"`
	}

	regionQuery := `SELECT drm.region_nom, COUNT(*) as count 
                    FROM subscribers s 
                    LEFT JOIN departement_region_mapping drm ON s.departement_numero = drm.departement_numero 
                    WHERE s.status = 'enabled' AND drm.region_nom IS NOT NULL
                    GROUP BY drm.region_nom 
                    ORDER BY count DESC`

	if err := a.db.Select(&regionStats, regionQuery); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	stats.ByRegion = make(map[string]int)
	for _, stat := range regionStats {
		stats.ByRegion[stat.Region] = stat.Count
	}

	// Statistics by department
	var deptStats []struct {
		Departement string `db:"departement_numero"`
		Count       int    `db:"count"`
	}

	deptQuery := `SELECT departement_numero, COUNT(*) as count 
                  FROM subscribers 
                  WHERE status = 'enabled' AND departement_numero IS NOT NULL AND departement_numero != '' 
                  GROUP BY departement_numero 
                  ORDER BY count DESC`

	if err := a.db.Select(&deptStats, deptQuery); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	stats.ByDepartement = make(map[string]int)
	for _, stat := range deptStats {
		stats.ByDepartement[stat.Departement] = stat.Count
	}

	// Statistics by CSP
	var cspStats []struct {
		CSP   string `db:"csp"`
		Count int    `db:"count"`
	}

	cspQuery := `SELECT csp, COUNT(*) as count 
                 FROM subscribers 
                 WHERE status = 'enabled' AND csp IS NOT NULL AND csp != '' 
                 GROUP BY csp 
                 ORDER BY count DESC`

	if err := a.db.Select(&cspStats, cspQuery); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	stats.ByCSP = make(map[string]int)
	for _, stat := range cspStats {
		stats.ByCSP[stat.CSP] = stat.Count
	}

	// Population statistics
	popQuery := `SELECT 
                    MIN(population_commune) as min_pop,
                    MAX(population_commune) as max_pop,
                    AVG(population_commune) as avg_pop,
                    SUM(population_commune) as total_pop
                 FROM subscribers 
                 WHERE status = 'enabled' AND population_commune > 0`

	var popStats struct {
		MinPop   int     `db:"min_pop"`
		MaxPop   int     `db:"max_pop"`
		AvgPop   float64 `db:"avg_pop"`
		TotalPop int     `db:"total_pop"`
	}

	if err := a.db.Get(&popStats, popQuery); err != nil {
		return echo.NewHTTPError(http.StatusInternalServerError, 
			a.i18n.T("globals.messages.errorFetching"))
	}

	stats.PopulationStats = models.PopulationStats{
		Min:   popStats.MinPop,
		Max:   popStats.MaxPop,
		Avg:   popStats.AvgPop,
		Total: popStats.TotalPop,
	}

	return c.JSON(http.StatusOK, okResp{stats})
}