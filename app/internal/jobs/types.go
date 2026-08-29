package jobs

import "time"

const MessageVersion = 1

type Message struct {
	Version     int       `json:"version"`
	JobID       string    `json:"job_id"`
	Payload     string    `json:"payload"`
	SubmittedAt time.Time `json:"submitted_at"`
	Traceparent string    `json:"traceparent,omitempty"`
}

type Result struct {
	Version     int       `json:"version"`
	JobID       string    `json:"job_id"`
	Status      string    `json:"status"`
	Digest      string    `json:"digest,omitempty"`
	CompletedAt time.Time `json:"completed_at,omitempty"`
	ErrorCode   string    `json:"error_code,omitempty"`
}

type StatusResponse struct {
	JobID  string  `json:"job_id"`
	Status string  `json:"status"`
	Result *Result `json:"result,omitempty"`
}
