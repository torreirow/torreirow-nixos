package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
)

const (
	maxLinks       = 5
	maxLinkLength  = 2048
	maxTitleLength = 200
)

// link is one video link from the form. Title starts as what the uploader
// typed and is filled in by fetchTitles when left empty.
type link struct {
	URL      string
	Title    string
	platform string
}

// platforms maps an allowed host (and its subdomains) to the fallback title.
var platforms = []struct{ host, label string }{
	{"youtube.com", "YouTube-video"},
	{"youtu.be", "YouTube-video"},
	{"facebook.com", "Facebook-video"},
	{"fb.watch", "Facebook-video"},
	{"instagram.com", "Instagram-reel"},
	{"vimeo.com", "Vimeo-video"},
}

// oEmbed endpoints that work without an API token; Facebook and Instagram
// need a Meta app token and are deliberately not called.
var (
	oembedEndpoints = map[string]string{
		"YouTube-video": "https://www.youtube.com/oembed?format=json&url=",
		"Vimeo-video":   "https://vimeo.com/api/oembed.json?url=",
	}
	oembedClient = &http.Client{Timeout: 5 * time.Second}
)

func platformOf(host string) (string, bool) {
	host = strings.ToLower(host)
	for _, p := range platforms {
		if host == p.host || strings.HasSuffix(host, "."+p.host) {
			return p.label, true
		}
	}
	return "", false
}

// parseLinks collects linkN/titelN form fields in order of N and checks them
// against the allowlist. Empty link fields are skipped.
func parseLinks(fields map[string]string) ([]link, error) {
	var nums []int
	for k, v := range fields {
		if n, err := strconv.Atoi(strings.TrimPrefix(k, "link")); err == nil && strings.HasPrefix(k, "link") && v != "" {
			nums = append(nums, n)
		}
	}
	if len(nums) > maxLinks {
		return nil, fmt.Errorf("%w: Je kunt maximaal %d links per keer insturen.", errValidation, maxLinks)
	}
	sort.Ints(nums)

	links := make([]link, 0, len(nums))
	for _, n := range nums {
		raw := fields["link"+strconv.Itoa(n)]
		title := oneLine(fields["titel"+strconv.Itoa(n)])
		if len(raw) > maxLinkLength || len([]rune(title)) > maxTitleLength {
			return nil, fmt.Errorf("%w: Link %d of de titel ervan is te lang.", errValidation, n)
		}
		u, err := url.Parse(raw)
		platform, ok := "", false
		if err == nil && u.Scheme == "https" {
			platform, ok = platformOf(u.Hostname())
		}
		if !ok {
			return nil, fmt.Errorf("%w: Link %d kunnen we niet gebruiken. Alleen links van YouTube, "+
				"Facebook, Instagram en Vimeo werken.", errValidation, n)
		}
		links = append(links, link{URL: raw, Title: title, platform: platform})
	}
	return links, nil
}

// fetchTitles fills empty titles from oEmbed (YouTube, Vimeo) in parallel and
// falls back to the platform name. It never fails the submission.
func fetchTitles(ctx context.Context, links []link) {
	var wg sync.WaitGroup
	for i := range links {
		if links[i].Title != "" {
			continue
		}
		endpoint, ok := oembedEndpoints[links[i].platform]
		if !ok {
			links[i].Title = links[i].platform
			continue
		}
		wg.Add(1)
		go func(l *link) {
			defer wg.Done()
			if t := oembedTitle(ctx, endpoint+url.QueryEscape(l.URL)); t != "" {
				l.Title = t
			} else {
				l.Title = l.platform
			}
		}(&links[i])
	}
	wg.Wait()
}

func oembedTitle(ctx context.Context, endpoint string) string {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return ""
	}
	resp, err := oembedClient.Do(req)
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	var d struct {
		Title  string `json:"title"`
		Author string `json:"author_name"`
	}
	if resp.StatusCode != http.StatusOK || json.NewDecoder(resp.Body).Decode(&d) != nil {
		return ""
	}
	title, author := oneLine(d.Title), oneLine(d.Author)
	if title == "" {
		return ""
	}
	if author != "" {
		title = fmt.Sprintf("%s (%s)", title, author)
	}
	if r := []rune(title); len(r) > maxTitleLength {
		title = string(r[:maxTitleLength])
	}
	return title
}

// renderLinks produces video-links.txt: number, title and link per item,
// a blank line between items, CRLF line endings.
func renderLinks(links []link) []byte {
	blocks := make([]string, len(links))
	for i, l := range links {
		blocks[i] = fmt.Sprintf("%d\r\n%s\r\n%s\r\n", i+1, l.Title, l.URL)
	}
	return []byte(strings.Join(blocks, "\r\n"))
}

// oneLine removes control characters (including line breaks), so text from
// the uploader cannot break the line-based file formats.
func oneLine(s string) string {
	return strings.TrimSpace(strings.Map(func(r rune) rune {
		if unicode.IsControl(r) {
			return ' '
		}
		return r
	}, s))
}
