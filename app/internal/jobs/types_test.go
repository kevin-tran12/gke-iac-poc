package jobs

import (
	"encoding/json"
	"testing"
	"time"
)

func TestMessageContract(t *testing.T) {
	m := Message{Version: MessageVersion, JobID: "id", Payload: "safe", SubmittedAt: time.Unix(0, 0).UTC()}
	b, err := json.Marshal(m)
	if err != nil {
		t.Fatal(err)
	}
	const want = `{"version":1,"job_id":"id","payload":"safe","submitted_at":"1970-01-01T00:00:00Z"}`
	if string(b) != want {
		t.Fatalf("got %s, want %s", b, want)
	}
}
