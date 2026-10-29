package main

import (
	"encoding/json"
	"fmt"
	"log"
	"os"
	"path/filepath"
	"strconv"
	"sync"
	"time"
)

// Quotas over a sliding window, persisted so a restart does not reset them.
// A slot is reserved only after the captcha passed, so bots without a valid
// captcha cannot use up the quota of real uploaders.

type limitConfig struct {
	perIPHour, perIPDay, totalDay int
	bytesDay                      int64
	stateFile                     string
}

type entry struct {
	ID    int64  `json:"id"`
	T     int64  `json:"t"`
	IP    string `json:"ip"`
	Bytes int64  `json:"bytes"`
}

type limitState struct {
	Entries   []entry `json:"entries"`
	LastAlert int64   `json:"lastAlert"`
}

var (
	limits  limitConfig
	limitMu sync.Mutex
)

func envInt(name string) int64 {
	v, err := strconv.ParseInt(mustEnv(name), 10, 64)
	if err != nil {
		log.Fatalf("%s: %v", name, err)
	}
	return v
}

func loadLimits() limitConfig {
	return limitConfig{
		perIPHour: int(envInt("LIMIT_PER_IP_HOUR")),
		perIPDay:  int(envInt("LIMIT_PER_IP_DAY")),
		totalDay:  int(envInt("LIMIT_TOTAL_DAY")),
		bytesDay:  envInt("LIMIT_BYTES_DAY"),
		stateFile: filepath.Join(mustEnv("STATE_DIRECTORY"), "ratelimit.json"),
	}
}

func readState() limitState {
	var s limitState
	if data, err := os.ReadFile(limits.stateFile); err == nil {
		if err := json.Unmarshal(data, &s); err != nil {
			log.Printf("ratelimit state unreadable, starting empty: %v", err)
		}
	}
	cutoff := time.Now().Add(-24 * time.Hour).Unix()
	kept := s.Entries[:0]
	for _, e := range s.Entries {
		if e.T > cutoff {
			kept = append(kept, e)
		}
	}
	s.Entries = kept
	return s
}

func writeState(s limitState) {
	data, _ := json.Marshal(s)
	tmp := limits.stateFile + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		log.Printf("ratelimit state write: %v", err)
		return
	}
	if err := os.Rename(tmp, limits.stateFile); err != nil {
		log.Printf("ratelimit state rename: %v", err)
	}
}

// reserve claims one submission slot for ip, or returns a validation error
// with a message for the uploader.
func reserve(ip string) (int64, error) {
	limitMu.Lock()
	defer limitMu.Unlock()

	s := readState()
	now := time.Now()
	hourAgo := now.Add(-time.Hour).Unix()
	var ipHour, ipDay int
	var bytesDay int64
	for _, e := range s.Entries {
		bytesDay += e.Bytes
		if e.IP == ip {
			ipDay++
			if e.T > hourAgo {
				ipHour++
			}
		}
	}

	switch {
	case ipHour >= limits.perIPHour || ipDay >= limits.perIPDay:
		log.Printf("limit: %s reached per-IP quota (hour=%d day=%d)", ip, ipHour, ipDay)
		return 0, fmt.Errorf("%w: Je hebt het maximum aantal uploads bereikt. Probeer het later opnieuw.", errValidation)
	case len(s.Entries) >= limits.totalDay || bytesDay >= limits.bytesDay:
		log.Printf("limit: global quota reached (uploads=%d bytes=%d)", len(s.Entries), bytesDay)
		if now.Unix()-s.LastAlert > 24*3600 {
			s.LastAlert = now.Unix()
			writeState(s)
			go notify(fmt.Sprintf("🛑 upload.toorren.net: daglimiet bereikt (%d uploads, %s in 24 uur). "+
				"Nieuwe uploads worden geweigerd tot het venster vrijkomt.", len(s.Entries), human(bytesDay)))
		}
		return 0, fmt.Errorf("%w: Er is vandaag al veel geüpload. Probeer het morgen opnieuw.", errValidation)
	}

	id := now.UnixNano()
	s.Entries = append(s.Entries, entry{ID: id, T: now.Unix(), IP: ip})
	writeState(s)
	return id, nil
}

// account records the bytes actually stored for a reserved slot.
func account(id, n int64) {
	limitMu.Lock()
	defer limitMu.Unlock()
	s := readState()
	for i := range s.Entries {
		if s.Entries[i].ID == id {
			s.Entries[i].Bytes = n
			writeState(s)
			return
		}
	}
}
