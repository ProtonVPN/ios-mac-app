# Connection

Home of app-side VPN logic. Responsible for:
 - configuring, launching, stopping and communicating with the network extension process.
 - interfacing with the network extension process to refresh our VPN connection certificate.
 - connecting to the Local Agent server and observing/responding to local agent state changes and errors communicated by the Local Agent server, as well as applying features/settings requested by the user.

Network Extension-side logic is implemented mostly in the `NEHelper` package. The `NEPacketTunnelProvider` class is implemented separately for iOS and MacOS in their respective app targets. In the future, we want to replace these with the implementation in the `WireGuardExtension` package, as is the case on tvOS.

## Architecture

State is managed using TCA, with features/reducers that operate at varying levels of granularity.

### Leaf Features

`ExtensionManagerFeature`, `CertificateAuthenticationFeature` and `LocalAgentFeature` are concerned with the low-level implementation details of each corresponding mechanism.
Each of these leaf features aims to represent its state as an `enum` with as little additional state as possible, so that when combined, we can reason about the overall 'connection state'.
For example, `ExtensionManagerFeature` and `LocalAgentFeature` states aim to simply mirror the state of the network extension process and the Local Agent client, respectively.

Any information that needs to be communicated upward (to the parent/grandparent features) should ideally be either held in associated values of state cases, or be sent as *delegate* actions.

#### ExtensionManager

The network extension process is based on our `PacketTunnelProvider` implementation. `ExtensionManagerFeature` has the power to:
 - Request the system to start/stop the tunnel, with explicit `startTunnel`/ `stopTunnel` calls
 - Talk to the process using IPC (`sendMessage`). The system will start the process if possible so that it can respond to our app-side message.

In addition to starting the tunnel in response to explicit user actions inside the app, the extension can also be started:
 - by the user
   - by toggling the corresponding VPN configuration inside VPN system settings
   - by toggling the Control Centre VPN item
 - by the system via an on-demand rule trigger
   - e.g. due to some network activity

### CoreConnectionFeature

`CoreConnectionFeature` manages the communication between the different leaf features.
For example, when evaluating a connection intent, once the `ExtensionManagerFeature` has reported that the tunnel has entered the `.connected` state, and responded to the app with details of the logical server it has connected to, the `CoreConnectionFeature`'s job is to inform the `CertificateAuthenticationFeature` of this information so that it can load and/or request/refresh the certificate required to continue with the connection process.

Once again, this feature deals with implementation details/internal logic.

### ConnectionFeature

This feature deals with state calculation, and connection preparation.

State calculation involves transforming the *actual* core connection state into something user friendly. For example, after killing and relaunching the app while connected, we are technically briefly "connecting" to the Local Agent remote server, but in reality the tunnel has not been stopped, so it's more accurate to claim that the state is loading or something else less alarming to the user. It also helps reducing transitionary states that are otherwise ugly in the UI and may confuse the user.

Connection preparation is the process of selecting the best connection configuration to the server, including port and protocol selection. Since this involves pinging the server's endpoints, this must happen while the tunnel is disconnected. In the interest of providing a responsive UI, the user facing state is reported as connecting during preparation, even though all child components are inactive/disconnected

## Testing

We must maintain high test coverage of every feature and dependency implementation.
For higher level features, especially the `ConnectionFeature`, it is reasonable to use non-exhaustive testing and simply make assertions on state transitions.

To facilitate this, this `ConnectionTestSupport` and `CoreConnectionTestSupport` include helpers such as `stateChangePredicate`.
When using these, intermediate actions can be skipped, but all state change actions arrive and do so in the correct order.

There also exists a `ConnectionEnvironment` that allows for easier setup of test cases with less repetition.

### Bug-to-Test Ratio

When addressing bugs, it's recommended to add at least one test case that would have reproduced the bug.
This is facilitated being able to inspect actions processed by the connection feature as seen in user logs.
You should attempt to mock and configure dependencies in such a way that the same actions are processed by the test store, as lead to the bug in the first place.

## Contributing

Before merging any changes, please aim to cover all relevant branches of the logic you’ve worked on with tests.
