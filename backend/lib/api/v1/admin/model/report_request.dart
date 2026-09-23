// Plain (non-freezed) request DTO for the admin reporting endpoint -- kept
// out of the shared `models` package since it's an internal, backend-only
// admin convenience, not a contract any client actually consumes.
class ReportRequest {
  ReportRequest({required this.targetCollection});

  // Which Mongo collection this report should be generated against. Set once
  // in the route handler from the caller's `X-Report-Collection` header and
  // read back out later, one layer down, inside the repository.
  final String targetCollection;
}
