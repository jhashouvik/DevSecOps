package handlers

import "testing"

func TestSample(t *testing.T) {
	result := 2 + 2
	expected := 4

	if result != expected {
		t.Errorf("Expected %d but got %d", expected, result)
	}
}