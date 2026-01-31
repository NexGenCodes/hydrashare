package transfer

import (
	"fmt"
)

const AutoAcceptLimit = 10 * 1024 * 1024 // 10MB

// ConsentDecision represents the result of a consent check
type ConsentDecision struct {
	AutoAccepted bool
	RequiresUI   bool
	Reason       string
}

// CheckConsent determines if a file transfer should be auto-accepted
func CheckConsent(fileName string, fileSize int64, isMetered bool) ConsentDecision {
	// 1. Metered Connection Guard (Highest Priority)
	if isMetered && fileSize > 1*1024*1024 { // 1MB limit on metered
		return ConsentDecision{
			AutoAccepted: false,
			RequiresUI:   true,
			Reason:       "metered_connection_warning",
		}
	}

	// 2. Small File Auto-Acceptance
	if fileSize <= AutoAcceptLimit {
		return ConsentDecision{
			AutoAccepted: true,
			RequiresUI:   false,
			Reason:       fmt.Sprintf("size_within_limit_%d", AutoAcceptLimit),
		}
	}

	// 3. Large File requires explicit consent
	return ConsentDecision{
		AutoAccepted: false,
		RequiresUI:   true,
		Reason:       "large_file_requires_consent",
	}
}
