# Persistence

Implementation of and interfaces for persisting models such as information about servers.

## Architecture

`Persistence` defines interfaces for repositories used to fetch and persist servers as well as aggregate information such as groups and server endpoints.
The interface uses domain models from `Domain` such as 'VPNServer' instead of the internal record structures that implementations might use.

This comes with a performance overhead due to the need to convert between representations, but it should be negligable for normal use cases where the number of objects is not excessive.

## Interface Design & Usage

`ServerRepository` provides what is essentially a subset of CRUD operations for Logicals, Servers and Loads along with some grouping queries.
Queries are specified using an array of `VPNServerFilter`, which enables fetching servers, or groups of servers, filtered by parameters such as tier, server features, or country.
The order of results is controlled using `VPNServerOrder`.

```
// Returns aggregate information about server groups,
// for which at least one server supports p2p
// (filters are applied before grouping)
repository.groups(filteredBy: [.features(.p2p)])

// All free Swiss servers
repository.servers(
    filteredBy: [
        .maxTier(0),
        .kind(.country("CH"))
    ],
    orderedBy: .nameAscending
)
```

`RDBPersistence` (Relational Database Persistence), provides an implementation of repositories provided by `Persistence`.
It's built using [GRDB](https://swiftpackageindex.com/groue/grdb.swift).

It makes heavy use of the [Query Interface DSL](https://swiftpackageindex.com/groue/grdb.swift#user-content-the-query-interface), so it is recommended to familiarise yourself with their documentation.

### VPNServer vs ServerInfo

The main functions of interest are:

```
getFirstServer(filteredBy filters: [VPNServerFilter], orderedBy: VPNServerOrder) throws -> VPNServer?
getServers(filteredBy filters: [VPNServerFilter], orderedBy: VPNServerOrder) throws -> [ServerInfo]
getGroups(filteredBy filters: [VPNServerFilter]) -> [ServerGroupInfo]

```

The schema is designed for efficient selection of:
- aggregate information about groups of servers (`getGroups`)
- aggregate information about a set of servers and their endpoints (`getServers`)

It is possible to scan the whole logicals table and retrieve information about all groups with a single `SELECT` statement.
The same is true for selecting a group of servers.
Wherever possible, these methods should be used instead of retrieving full information about a server and its endpoints using `getFirstServer`.
At the present moment, this requires an additional `SELECT`, although this could be improved in the future if it is ever necessary to retrieve full information about a set of servers.

See [Schema](#schema) for more details.

## Schema

We define four tables, each of which is used with a record type.
`Logical` (holds the static information for each `Domain.Logical`), `Endpoint` (represents `Domain.ServerEndpoint`), `LogicalStatus` which holds the dynamic information from `Domain.Logical`, and `OverrideInfo` which holds per protocol override information for each endpoint.

In addition to these record types, Persistence defines some additional result types.
These do not have corresponding tables in the database, but are used to decode query results of table joins, along with associated objects, or annotated aggregate values.

These include:
- `GroupInfoResult` - Contains aggregate information about a group of logicals and their endpoints, such as the range of features it supports
- `ServerInfoResult` - Contains information about a `Logical` and aggregated endpoint information. Only one `SELECT` statement is required to fetch a set of server results, which makes this appropriate for e.g. displaying a list of servers in the UI
- `ServerResult` - Useful for cases where full information about a `Logical` and all of its endpoints is required, e.g. when attempting to connect to a selected `Logical`

These result types correspond to the following `Domain` models:
- `GroupInfoResult` - `ServerGroupInfo`
- `ServerInfoResult` - `ServerInfo`
- `ServerResult` - `VPNServerResult`

Refer to [Recommended Practices](https://swiftpackageindex.com/groue/grdb.swift/v6.23.0/documentation/grdb/recordrecommendedpractices#How-to-Model-Graphs-of-Objects) when making changes to the schema.

## Testing

`Dependencies` will auto-fail any logic that accesses `serverRepository` without providing a mock implementation.
We use value types to define `serverRepository` instead of a protocol, meaning only the methods which are actually used by the system under test, need to be implemented.
For unit tests, it's sufficient to provide a minimal interface:

```
func testSUTDoesntBurnWhenServerListIsEmpty() {
    withDependencies {
        $0.serverRepository = .init(servers: [])
    } operation: {
        ... // something in operation invokes serverRepository.getServers(filteredBy: ..., orderedBy: ...)
    }
}

```

For integration tests, using the live implementation of the server repository is preferred, as long as an in-memory database is specified.
This results in higher test coverage and less likelihood of incorrectly implementing a mock.

`PersistenceTestSupport` provides specialised `XCTestCase` subclasses that manage an in-memory repository for you.
See `TestIsolatedDatabaseTestCase` and `CaseIsolatedDatabaseTestCase` for more details.

Alternatively, if you must subclass a different `XCTestCase`, you can implement the `TestIsolatedDatabaseTestDriver` or `CaseIsolatedDatabaseTestDriver` protocols instead.
There is also the possibility to override the `DatabaseConfigurationKey` dependency yourself:

```
let repositoryImplementation = withDependencies {
    $0.databaseConfiguration = .withTestExecutor(databaseType: .ephemeral)
} operation: {
    ServerRepository.liveValue
}
```

## Migrations

Every time a new app version is shipped, where the schema has been changed since the last version, we must create an explicit migration.
This includes beta releases, and builds that revert to an older schema version.

In the case where the app discovers the database has been updated to an unknown version, beyond what the current build has knowledge of:
 - RELEASE builds will log an error and attempt to delete the existing database and recreate an empty one, even if we might have been able to continue without errors (it's possible the migration may have been compatible, e.g. if a column or index was added)
 - DEBUG builds will trigger an assertion failure for visibility. There is no point in continuing in this scenario - it would be a serious error to release a build to production that removes/changes existing migrations

 The only situation where this can happen in production, is when a user intentionally installs an older app version without first clearing app data.

### How to Ship Reverts

Reverts describe the scenario where a serious issue is discovered with an app version that has been released to the public, and a new version must be pushed out that is based on an earlier schema version.

Given the following events:
 - App version A1 is released with schema version S1
 - App version A2 is released with schema version S2
   - Provides schema migration S1 -> S2
   - A2 is discovered to contain a serious issue that must be reverted
   - A1 is the earliest safe candidate to revert to

The migration from S1 -> S2 must **NOT** be reverted.
Additionally, if S2 is not compatible with A1 (e.g. a column has been removed or renamed), an explicit S2 -> S3 migration must be provided, where S3 is equivalent to S1.

## FAQ

### Why Synchronous API?

Disk-based SQLite with optimised tables and queries should be very fast, even with very large statements and queries.
If we hit a performance roadblock, we can always start loading the database to memory on app init, perform queries and updates in-memory, and persist after updating when necessary.

Some of the larger operations like persisting the whole initial server list can always be wrapped in a task and performed in the background, without the repository interface needing to be asynchronous.

### Record Structs & DSL

Separating domain models and database records and relying on GRDB's query interface has ergonomic benefits but requires using multiple intermediate representations.
Implementation specific structs such as `Logical` live in the RDBPersistence/Logicals/Schema folder.

## Future Work

### Relational DB Optimization

- Investigate adding further indexes, using the `EXPLAIN QUERY PLAN` feature of SQLite to highlight areas of concern
- Improve text search (see `sqlExpression` implementation of `VPNServerFilter.matches`)

### Additional Candidates for Persistence

 - Profiles/Recents
   - Or at least refer to them by ID instead of serializing the whole object with `NSCoding`
