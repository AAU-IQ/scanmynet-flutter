package com.creativeadvtech.scanmynet_sdk

import com.creative.tools.rest.dto.response.*

/**
 * Maps the SDK's response DTOs onto the Pigeon report types.
 *
 * Null in, null out: an absent section stays absent rather than becoming an
 * empty object, so Dart can distinguish "not measured" from "measured empty".
 */
internal fun ReportDto.toPigeon() = ReportData(
    customerDetails = customer_details?.toPigeon(),
    sdkDetails = sdk_details?.toPigeon(),
    routerUsageDuringScan = router_usage_during_scan?.toPigeon(),
    customerInternetSpeed = customer_internet_speed?.toPigeon(),
    basicConnectivity = basic_connectivity?.toPigeon(),
    localConnectedDevices = local_connected_devices?.map { it.toPigeon() },
    customerRouterDetails = customer_router_details?.toPigeon(),
    networkTopology = network_topology?.toPigeon(),
    userWifiNetwork = user_wifi_network?.toPigeon(),
    networkCongestion = network_congestion?.toPigeon(),
    connectionQuality = connection_quality?.map { it.toPigeon() },
    traceroute = traceroute?.map { it.toPigeon() },
    alerts = alerts?.map { it.toPigeon() },
    actions = actions?.map { it.toPigeon() },
    incompleteAnalysis = incomplete_analysis,
)

internal fun CustomerDetailsDto.toPigeon() = CustomerDetails(
    key = key,
    lastKnownPublicIp = last_known_public_ip,
    // Capitalised keys pass through verbatim — no case transformation.
    lastKnownPublicIpDetails = last_known_public_ip_details,
)

internal fun SdkDetailsDto.toPigeon() = SdkDetails(
    start = start,
    duration = duration,
    platform = platform,
    app = app,
    routeThisSdk = route_this_sdk,
    userPublicUpAddress = user_public_up_address,
    gpsLatitude = gps_latitude,
    gpsLongitude = gps_longitude,
)

internal fun RouterUsageDto.toPigeon() = RouterUsage(
    networkUsageDown = network_usage_down,
    networkUsageUp = network_usage_up,
)

internal fun InternetSpeedDto.toPigeon() = InternetSpeed(
    networkSpeedDown = network_speed_down,
    networkSpeedUp = network_speed_up,
    currentNegotiatedLinkSpeed = current_negotiated_link_speed,
    maximumLinkSupportedByPhone = maximum_link_supported_by_phone,
    networkSpeedUpSegments = network_speed_up_segments,
    networkSpeedDownSegments = network_speed_down_segments,
    // Single-entry map keyed by label — passed through as-is, NOT flattened.
    connectionQuality = connection_quality,
)

internal fun BasicConnectivityDto.toPigeon() = BasicConnectivity(
    ipAssignedViaDhcp = ip_assigned_via_dhcp,
    serverConnectivity = server_connectivity?.map { it.toPigeon() },
    portChecks = port_checks?.map { it.toPigeon() },
    dnsLookup = dns_lookup?.map { it.toPigeon() },
    summary = summary?.toPigeon(),
    blockedServers = servers,
    blockedUdpPorts = udp,
    blockedTcpPorts = tcp,
    firewall = firewall?.toPigeon(),
    clientIsolation = client_isolation?.toPigeon(),
    multicast = multicast?.toPigeon(),
    // basic_connectivity.alerts is always empty — intentionally dropped.
)

internal fun ServerConnectivityResultDto.toPigeon() =
    ServerConnectivityResult(name = name, serverStatus = server_status)

internal fun PortCheckDto.toPigeon() = PortCheckResult(
    port = port, portType = port_type, description = description, portStatus = port_status,
)

internal fun DnsLookupResultDto.toPigeon() =
    DnsLookupResult(dnsIp = dns_ip, alias = alias, reverseDns = reverse_dns)

internal fun ConnectivitySummaryDto.toPigeon() = ConnectivitySummary(
    serverConnectivity = server_connectivity?.toPigeon(),
    portChecks = port_checks?.toPigeon(),
    dnsLookup = dns_lookup,
)

internal fun StatusColorDto.toPigeon() = StatusColor(status = status, color = color)

internal fun ToggleStateDto.toPigeon() = ToggleState(
    value = value, color = color, status = status, alert = alerts?.toPigeon(),
)

internal fun AlertDto.toPigeon() =
    ReportAlert(alertType = alert_type, alertValue = alert_value)

internal fun ActionDto.toPigeon() =
    ReportAction(actionType = action_type, actionValue = action_value)

internal fun LocalConnectedDeviceDto.toPigeon() = LocalConnectedDevice(
    deviceName = device_name,
    deviceIp = device_ip,
    deviceMacAddress = device_mac_address,
    manufacturer = manufacturer,
    packetsDropped = packets_dropped,
    numPacketsSent = num_packets_sent,
    pingValues = ping_values,
    isSubscriberPhone = is_subscriber_phone,
    averagePingTime = average_ping_time,
    connectionQualityColor = connection_quality_color?.toPigeon(),
    isSubscriberRouter = is_subscriber_router,
    deviceDetails = device_details?.toPigeon(),
)

internal fun QualityColorDto.toPigeon() = QualityColor(quality = quality, color = color)

internal fun DeviceRecognitionDto.toPigeon() =
    DeviceRecognition(mac = mac, recognition = recognition)

internal fun CustomerRouterDetailsDto.toPigeon() = CustomerRouterDetails(
    make = make, model = model, encryption = encryption, protocols = protocols,
    mesh = mesh, routerIpAddress = router_ip_address,
    routerMacAddress = router_mac_address, manufacturer = manufacturer,
    hostname = hostname, modelDescription = model_description,
    modelNumber = model_number, friendlyName = friendly_name,
    deviceType = device_type, routerDetails = router_details?.toPigeon(),
)

internal fun NetworkTopologyDto.toPigeon() = NetworkTopology(
    routerIpAddress = router_ip_address,
    otherRouters = other_routers,
    otherRoutersDetails = other_routers_details?.map { it.toPigeon() },
    doubleNatDetected = double_nat_detected?.toPigeon(),
)

internal fun OtherRouterDetailDto.toPigeon() =
    OtherRouterDetail(ip = ip, asn = asn, owner = owner)

internal fun DoubleNatDto.toPigeon() =
    DoubleNat(isDoubleNat = is_double_nat, doubleNatHop = double_nat_hop)

internal fun WifiNetworkResultDto.toPigeon() = WifiNetworkResult(
    ssid = ssid, ssidIp = ssid_ip, bssid = bssid, encryption = encryption,
    frequency = frequency, wpsAvailability = wps_availability,
    signalStrength = signal_strength, numWifiChannels = num_wifi_channels,
    channelWidth = channel_width, currentChannel = current_channel,
    isSubscriberSsid = is_subscriber_ssid,
)

internal fun NetworkCongestionDto.toPigeon() = NetworkCongestion(
    userConnection = user_connection?.toPigeon(),
    environment = environment?.toPigeon(),
)

internal fun UserConnectionDto.toPigeon() = UserConnection(
    phoneWifiFrequency = phone_wifi_frequency,
    numPhoneWifiChannel = num_phone_wifi_channel,
    numNetworksOnChannel = num_networks_on_channel,
    phoneWifiChannel = phone_wifi_channel,
)

internal fun CongestionEnvironmentDto.toPigeon() = CongestionEnvironment(
    channelCongestion = channel_congestion?.map { it.toPigeon() },
    surroundingWifiNetworks = surrounding_wifi_networks?.map { it.toPigeon() },
)

/** [ChannelCongestionDto.index] is a String and stays one. */
internal fun ChannelCongestionDto.toPigeon() =
    ChannelCongestion(index = index, numNetworks = num_networks)

internal fun DnsQualityDto.toPigeon() = DnsQuality(
    dnsName = dns_name, dnsIp = dns_ip, packetsDropped = packets_dropped,
    numPacketsSent = num_packets_sent, pingValues = ping_values,
    isSubscriberRouter = is_subscriber_router, jitter = jitter,
    averagePingTime = average_ping_time,
    connectionQualityColor = connection_quality_color?.toPigeon(),
    layerRanking = layer_ranking,
)

internal fun TracerouteResultDto.toPigeon() = TracerouteEntry(
    dnsDestinationIp = dns_destination_ip,
    hops = hops?.map { it.toPigeon() },
)

internal fun TracerouteHopDto.toPigeon() =
    TracerouteHop(dnsIp = dns_ip, dnsName = dns_name, rttValues = rtt_values)
