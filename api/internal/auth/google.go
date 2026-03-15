package auth

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

const tokenInfoURL = "https://oauth2.googleapis.com/tokeninfo?id_token="

type GoogleUserInfo struct {
	Sub         string `json:"sub"`
	Email       string `json:"email"`
	Name        string `json:"name"`
	Picture     string `json:"picture"`
	EmailVerified string `json:"email_verified"`
}

// VerifyGoogleIDToken validates a Google ID token and returns user info.
func VerifyGoogleIDToken(ctx context.Context, idToken string) (*GoogleUserInfo, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, tokenInfoURL+idToken, nil)
	if err != nil {
		return nil, err
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("google token verification failed: status %d", resp.StatusCode)
	}

	var info GoogleUserInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, err
	}
	if info.Email == "" {
		return nil, fmt.Errorf("google token missing email claim")
	}
	return &info, nil
}
