//
//  Created on 07/12/2023.
//
//  Copyright (c) 2023 Proton AG
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.

import Foundation

import GRDB

import Domain

extension QueryInterfaceRequest {
    public func filterServers(
        _ filters: [VPNServerFilter],
        logicalAlias: TableAlias,
        statusAlias: TableAlias,
        overrideAlias: TableAlias
    ) -> Self {
        return filters
            .map { $0.sqlExpression(logical: logicalAlias, status: statusAlias, overrides: overrideAlias) }
            .reduce(self) { request, sqlExpression in request.filter(sqlExpression) }
    }

    public func order(
        _ serverOrder: VPNServerOrder,
        logicalAlias: TableAlias,
        statusAlias: TableAlias
    ) -> Self {
        switch serverOrder {
        case .none:
            return self

        case .random:
            return order(statusAlias[LogicalStatus.Columns.status].desc, SQL("RANDOM()"))

        case .fastest:
            // We could also sort by tier descending, but API should return lower scores for servers with higher tier
            // It would also require a more complicated cross-table index
            return order(statusAlias[LogicalStatus.Columns.status].desc, statusAlias[LogicalStatus.Columns.score].asc)

        case .nameAscending:
            return order(logicalAlias[Logical.Columns.namePrefix].asc, logicalAlias[Logical.Columns.sequenceNumber].asc)
        }
    }

    func ordering(by groupOrder: VPNServerGroupOrder, logicalAlias: TableAlias) -> Self {
        switch groupOrder {
        case .exitCountryCodeAscending:
            return order(
                logicalAlias[Logical.Columns.gatewayName].ascNullsLast,
                logicalAlias[Logical.Columns.exitCountryCode].asc
            )
        case .localizedCountryNameAscending:
            return order(
                logicalAlias[Logical.Columns.gatewayName].ascNullsLast,
                localizedCountryName(logicalAlias[Logical.Columns.exitCountryCode]).asc
            )
        }
    }
}

// MARK: GroupInfoResult

extension Endpoint {
    /// Define joins on Endpoint, also setting up table aliases so that they can be used to reference columns in future
    /// operations such as filtering.
    ///
    /// Joins performed:
    /// - Left join with EndpointOverrides
    /// - Inner join Logical and LogicalStatus (transitively)
    static func joiningAndAliasing(
        logicalAlias: TableAlias,
        statusAlias: TableAlias,
        overrideAlias: TableAlias
    ) -> QueryInterfaceRequest<Endpoint> {
        Endpoint
            .joining(
                required: Endpoint.logical
                    .aliased(logicalAlias).select(Logical.Columns.exitCountryCode, Logical.Columns.gatewayName)
                    .joining(required: Logical.status.aliased(statusAlias))
            )
            .joining(optional: Endpoint.overrides.aliased(overrideAlias))
    }
}

extension QueryInterfaceRequest where RowDecoder == Endpoint {

    /// Represents the condition of whether a logical server is virtual (a.k.a. supports smart routing or not)
    private func isVirtual(_ logicalAlias: TableAlias) -> SQLExpression {
        let exitCountryCode = logicalAlias[Logical.Columns.exitCountryCode]
        let hostCountry = logicalAlias[Logical.Columns.hostCountry]
        return SQL(
            """
            CASE
            WHEN \(hostCountry) IS NOT NULL AND \(hostCountry) != \(exitCountryCode)
            THEN 1
            ELSE 0
            END
            """
        ).sqlExpression
    }

    /// Annotates the request with aggregate information collected from joined tables using the provided aliases
    func annotatedWithAggregateData(
        logicalAlias: TableAlias,
        statusAlias: TableAlias,
        overrideAlias: TableAlias
    ) -> QueryInterfaceRequest<Endpoint> {
        return self
            .annotated(with: max(statusAlias[LogicalStatus.Columns.status] & Endpoint.Columns.status).forKey("status"))
            .annotated(with: bitwiseAnd(isVirtual(logicalAlias)).forKey("isVirtual"))
            .annotated(with: count(distinct: logicalAlias[Logical.Columns.id]).forKey("serverCount"))
            .annotated(with: count(distinct: logicalAlias[Logical.Columns.city]).forKey("cityCount"))
            .annotated(with: logicalAlias[Logical.Columns.exitCountryCode])
            .annotated(with: logicalAlias[Logical.Columns.gatewayName])
            .annotated(with: bitwiseOr(logicalAlias[Logical.Columns.feature]).forKey("featureUnion"))
            .annotated(with: bitwiseAnd(logicalAlias[Logical.Columns.feature]).forKey("featureIntersection"))
            .annotated(with: bitwiseOr(overrideAlias[EndpointOverrides.Columns.protocolMask] ?? ProtocolSupport.all.rawValue).forKey("protocolSupport"))
            .annotated(with: min(logicalAlias[Logical.Columns.tier]).forKey("minTier"))
            .annotated(with: max(logicalAlias[Logical.Columns.tier]).forKey("maxTier"))
            .annotated(with: logicalAlias[Logical.Columns.latitude])
            .annotated(with: logicalAlias[Logical.Columns.longitude])
    }

    func groupingByServerType(logicalAlias: TableAlias) -> QueryInterfaceRequest<GroupInfoResult> {
        return self
            .group(logicalAlias[Logical.Columns.gatewayName], logicalAlias[Logical.Columns.exitCountryCode])
            .asRequest(of: GroupInfoResult.self)
    }
}

extension GroupInfoResult {

    static func request(
        filters: [VPNServerFilter],
        groupOrder: VPNServerGroupOrder
    ) -> QueryInterfaceRequest<GroupInfoResult> {
        let logicals = TableAlias()
        let statuses = TableAlias()
        let overrides = TableAlias()

        return Endpoint
            .joiningAndAliasing(logicalAlias: logicals, statusAlias: statuses, overrideAlias: overrides)
            .filterServers(filters, logicalAlias: logicals, statusAlias: statuses, overrideAlias: overrides)
            .annotatedWithAggregateData(logicalAlias: logicals, statusAlias: statuses, overrideAlias: overrides)
            .groupingByServerType(logicalAlias: logicals)
            .ordering(by: groupOrder, logicalAlias: logicals)
    }
}

// MARK: ServerResult

extension ServerResult {
    static func request(filters: [VPNServerFilter], order: VPNServerOrder) -> QueryInterfaceRequest<ServerResult> {
        let endpointAlias = TableAlias()
        let logicalAlias = TableAlias()
        let statusAlias = TableAlias()
        let overrideAlias = TableAlias()

        return Logical.aliased(logicalAlias)
            .including(all: Logical.endpoints.including(optional: Endpoint.overrides))
            .joining(
                required: Logical.endpoints.aliased(endpointAlias)
                    .joining(optional: Endpoint.overrides.aliased(overrideAlias))
            )
            .including(required: Logical.status.aliased(statusAlias))
            .filterServers(filters, logicalAlias: logicalAlias, statusAlias: statusAlias, overrideAlias: overrideAlias)
            .asRequest(of: ServerResult.self)
            .group(logicalAlias[Logical.Columns.id])
            .order(order, logicalAlias: logicalAlias, statusAlias: statusAlias)
    }
}

extension ServerInfoResult {
    static func request(filters: [VPNServerFilter], order: VPNServerOrder) -> QueryInterfaceRequest<ServerInfoResult> {
        let logicalAlias = TableAlias()
        let statusAlias = TableAlias()
        let overrideAlias = TableAlias()

        return Endpoint
            .including(required: Endpoint.logical.aliased(logicalAlias).including(required: Logical.status.aliased(statusAlias)))
            .joining(optional: Endpoint.overrides.aliased(overrideAlias))
            .annotated(with: bitwiseOr(overrideAlias[EndpointOverrides.Columns.protocolMask]).forKey("protocolMask"))
            .filterServers(filters, logicalAlias: logicalAlias, statusAlias: statusAlias, overrideAlias: overrideAlias)
            .asRequest(of: ServerInfoResult.self)
            .group(logicalAlias[Logical.Columns.id])
            .order(order, logicalAlias: logicalAlias, statusAlias: statusAlias)
    }
}
