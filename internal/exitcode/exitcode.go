// Package exitcode declares the typed sentinel exit codes the doctor returns
// to the operator's shell. Allocation per cli-surface.md § Exit code allocation.
package exitcode

// Code is a process exit code. The zero value is Success.
type Code int

const (
	Success                           Code = 0
	GenericError                      Code = 1
	RunningNode                       Code = 2
	AheadOfCanonical                  Code = 3
	VersionMismatch                   Code = 4
	Capacity                          Code = 5
	PermissionReadOnly                Code = 6
	ManifestFormatVersionUnrecognized Code = 7
)
