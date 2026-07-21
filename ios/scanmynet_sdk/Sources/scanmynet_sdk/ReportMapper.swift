import Foundation
import ScanMyNet

/// Maps the native `ScanMyNet` SDK's `SMN*` report models onto the Pigeon report
/// types (`ReportData` and its sections).
///
/// This is the iOS counterpart of the Android `ReportMapper.kt`; both feed the
/// same Pigeon `ScanResult.report`, so the two must stay field-for-field aligned.
///
/// Two rules run throughout:
///
///   * **Null in, null out** — an absent section stays absent rather than becoming
///     an empty object, so Dart can tell "not measured" from "measured empty".
///   * **`Int` -> `Int64` widening** — Pigeon models Dart `int` as Swift `Int64`,
///     while the SDK models use the native `Int`. Every integer field is widened
///     with `{ Int64($0) }`; omitting this is a compile error, not a silent bug.
extension SMNReportPayload {
  func toPigeon() -> ReportData {
    ReportData(
      customerDetails: customerDetails?.toPigeon(),
      sdkDetails: sdkDetails?.toPigeon(),
      routerUsageDuringScan: routerUsageDuringScan?.toPigeon(),
      customerInternetSpeed: customerInternetSpeed?.toPigeon(),
      basicConnectivity: basicConnectivity?.toPigeon(),
      localConnectedDevices: localConnectedDevices?.map { $0.toPigeon() },
      customerRouterDetails: customerRouterDetails?.toPigeon(),
      networkTopology: networkTopology?.toPigeon(),
      userWifiNetwork: userWifiNetwork?.toPigeon(),
      networkCongestion: networkCongestion?.toPigeon(),
      connectionQuality: connectionQuality?.map { $0.toPigeon() },
      traceroute: traceroute?.map { $0.toPigeon() },
      alerts: alerts?.map { $0.toPigeon() },
      actions: actions?.map { $0.toPigeon() },
      incompleteAnalysis: incompleteAnalysis
    )
  }
}

extension SMNCustomerDetails {
  func toPigeon() -> CustomerDetails {
    CustomerDetails(
      key: key,
      lastKnownPublicIp: lastKnownPublicIP,
      // Capitalised keys (`Country`, `Region`, `ISP`) pass through verbatim.
      lastKnownPublicIpDetails: lastKnownPublicIPDetails
    )
  }
}

extension SMNSDKDetails {
  func toPigeon() -> SdkDetails {
    SdkDetails(
      start: start,
      duration: duration.map { Int64($0) },
      platform: platform,
      app: app,
      routeThisSdk: routeThisSDK,
      userPublicUpAddress: userPublicUpAddress,
      gpsLatitude: gpsLatitude,
      gpsLongitude: gpsLongitude
    )
  }
}

extension SMNRouterUsage {
  func toPigeon() -> RouterUsage {
    RouterUsage(networkUsageDown: networkUsageDown, networkUsageUp: networkUsageUp)
  }
}

extension SMNInternetSpeed {
  func toPigeon() -> InternetSpeed {
    InternetSpeed(
      networkSpeedDown: networkSpeedDown,
      networkSpeedUp: networkSpeedUp,
      currentNegotiatedLinkSpeed: currentNegotiatedLinkSpeed,
      maximumLinkSupportedByPhone: maximumLinkSupportedByPhone,
      networkSpeedUpSegments: networkSpeedUpSegments,
      networkSpeedDownSegments: networkSpeedDownSegments,
      // Single-entry map keyed by label — passed through as-is, NOT flattened.
      connectionQuality: connectionQuality
    )
  }
}

extension SMNBasicConnectivity {
  func toPigeon() -> BasicConnectivity {
    BasicConnectivity(
      ipAssignedViaDhcp: ipAssignedViaDHCP,
      serverConnectivity: serverConnectivity?.map { $0.toPigeon() },
      portChecks: portChecks?.map { $0.toPigeon() },
      dnsLookup: dnsLookup?.map { $0.toPigeon() },
      summary: summary?.toPigeon(),
      blockedServers: servers,
      blockedUdpPorts: udp?.map { Int64($0) },
      blockedTcpPorts: tcp?.map { Int64($0) },
      firewall: firewall?.toPigeon(),
      clientIsolation: clientIsolation?.toPigeon(),
      multicast: multicast?.toPigeon()
      // basic_connectivity.alerts is always empty — intentionally dropped, as on Android.
    )
  }
}

extension SMNServerConnectivityResult {
  func toPigeon() -> ServerConnectivityResult {
    ServerConnectivityResult(name: name, serverStatus: serverStatus)
  }
}

extension SMNPortCheckResult {
  func toPigeon() -> PortCheckResult {
    PortCheckResult(
      port: port.map { Int64($0) },
      portType: portType,
      description: description,
      portStatus: portStatus
    )
  }
}

extension SMNDNSLookupResult {
  func toPigeon() -> DnsLookupResult {
    DnsLookupResult(dnsIp: dnsIP, alias: alias, reverseDns: reverseDNS)
  }
}

extension SMNConnectivitySummary {
  func toPigeon() -> ConnectivitySummary {
    ConnectivitySummary(
      serverConnectivity: serverConnectivity?.toPigeon(),
      portChecks: portChecks?.toPigeon(),
      dnsLookup: dnsLookup
    )
  }
}

extension SMNStatusColor {
  func toPigeon() -> StatusColor { StatusColor(status: status, color: color) }
}

extension SMNToggleState {
  func toPigeon() -> ToggleState {
    // SMN `alerts` is a single object (not a list) — maps to the singular `alert`.
    ToggleState(value: value, color: color, status: status, alert: alerts?.toPigeon())
  }
}

extension SMNReportAlert {
  func toPigeon() -> ReportAlert {
    ReportAlert(alertType: alertType, alertValue: alertValue)
  }
}

extension SMNReportAction {
  func toPigeon() -> ReportAction {
    ReportAction(actionType: actionType, actionValue: actionValue)
  }
}

extension SMNLocalConnectedDevice {
  func toPigeon() -> LocalConnectedDevice {
    LocalConnectedDevice(
      deviceName: deviceName,
      deviceIp: deviceIP,
      deviceMacAddress: deviceMacAddress,
      manufacturer: manufacturer,
      packetsDropped: packetsDropped,
      numPacketsSent: numPacketsSent.map { Int64($0) },
      pingValues: pingValues,
      isSubscriberPhone: isSubscriberPhone,
      averagePingTime: averagePingTime,
      connectionQualityColor: connectionQualityColor?.toPigeon(),
      isSubscriberRouter: isSubscriberRouter,
      deviceDetails: deviceDetails?.toPigeon()
    )
  }
}

extension SMNQualityColor {
  func toPigeon() -> QualityColor { QualityColor(quality: quality, color: color) }
}

extension SMNDeviceRecognition {
  func toPigeon() -> DeviceRecognition {
    // `recognition` is an open payload: unwrap each AnyCodable to its raw value
    // so the map becomes the `[String: Any?]` the channel codec expects.
    DeviceRecognition(mac: mac, recognition: recognition?.mapValues { $0.value })
  }
}

extension SMNCustomerRouterDetails {
  func toPigeon() -> CustomerRouterDetails {
    CustomerRouterDetails(
      make: make,
      model: model,
      encryption: encryption,
      protocols: protocols,
      mesh: mesh,
      routerIpAddress: routerIPAddress,
      routerMacAddress: routerMacAddress,
      manufacturer: manufacturer,
      hostname: hostname,
      modelDescription: modelDescription,
      modelNumber: modelNumber,
      friendlyName: friendlyName,
      deviceType: deviceType,
      routerDetails: routerDetails?.toPigeon()
    )
  }
}

extension SMNNetworkTopology {
  func toPigeon() -> NetworkTopology {
    NetworkTopology(
      routerIpAddress: routerIPAddress,
      otherRouters: otherRouters,
      otherRoutersDetails: otherRoutersDetails?.map { $0.toPigeon() },
      doubleNatDetected: doubleNatDetected?.toPigeon()
    )
  }
}

extension SMNOtherRouterDetail {
  func toPigeon() -> OtherRouterDetail {
    OtherRouterDetail(ip: ip, asn: asn.map { Int64($0) }, owner: owner)
  }
}

extension SMNDoubleNat {
  func toPigeon() -> DoubleNat {
    DoubleNat(isDoubleNat: isDoubleNat, doubleNatHop: doubleNatHop)
  }
}

extension SMNWifiNetworkResult {
  func toPigeon() -> WifiNetworkResult {
    WifiNetworkResult(
      ssid: ssid,
      ssidIp: ssidIP,
      bssid: bssid,
      encryption: encryption,
      frequency: frequency,
      wpsAvailability: wpsAvailability,
      signalStrength: signalStrength.map { Int64($0) },
      numWifiChannels: numWifiChannels.map { Int64($0) },
      channelWidth: channelWidth.map { Int64($0) },
      currentChannel: currentChannel.map { Int64($0) },
      isSubscriberSsid: isSubscriberSSID
    )
  }
}

extension SMNNetworkCongestion {
  func toPigeon() -> NetworkCongestion {
    NetworkCongestion(
      userConnection: userConnection?.toPigeon(),
      environment: environment?.toPigeon()
    )
  }
}

extension SMNUserConnection {
  func toPigeon() -> UserConnection {
    UserConnection(
      phoneWifiFrequency: phoneWifiFrequency,
      numPhoneWifiChannel: numPhoneWifiChannel.map { Int64($0) },
      numNetworksOnChannel: numNetworksOnChannel.map { Int64($0) },
      phoneWifiChannel: phoneWifiChannel.map { Int64($0) }
    )
  }
}

extension SMNCongestionEnvironment {
  func toPigeon() -> CongestionEnvironment {
    CongestionEnvironment(
      channelCongestion: channelCongestion?.map { $0.toPigeon() },
      surroundingWifiNetworks: surroundingWifiNetworks?.map { $0.toPigeon() }
    )
  }
}

/// `index` is a String in the payload and stays one.
extension SMNChannelCongestion {
  func toPigeon() -> ChannelCongestion {
    ChannelCongestion(index: index, numNetworks: numNetworks.map { Int64($0) })
  }
}

extension SMNDNSQuality {
  func toPigeon() -> DnsQuality {
    DnsQuality(
      dnsName: dnsName,
      dnsIp: dnsIP,
      packetsDropped: packetsDropped,
      numPacketsSent: numPacketsSent.map { Int64($0) },
      pingValues: pingValues,
      isSubscriberRouter: isSubscriberRouter,
      jitter: jitter,
      averagePingTime: averagePingTime,
      connectionQualityColor: connectionQualityColor?.toPigeon(),
      layerRanking: layerRanking.map { Int64($0) }
    )
  }
}

extension SMNTracerouteResultEntry {
  func toPigeon() -> TracerouteEntry {
    TracerouteEntry(
      dnsDestinationIp: dnsDestinationIP,
      hops: hops?.map { $0.toPigeon() }
    )
  }
}

extension SMNTracerouteHop {
  func toPigeon() -> TracerouteHop {
    TracerouteHop(dnsIp: dnsIP, dnsName: dnsName, rttValues: rttValues?.map { Int64($0) })
  }
}
