# Domain-Driven Design Patterns

## Strategic Patterns

### Bounded Context Identification

1. **Core Domain** — competitive advantage, invest the most effort here
2. **Supporting Domains** — necessary but not differentiating
3. **Generic Domains** — commodity functionality (auth, email, payments)

### Context Mapping

| Pattern | When to Use |
|---------|-------------|
| **Partnership** | Two teams jointly evolve two contexts |
| **Customer-Supplier** | Upstream supplies what downstream needs |
| **Conformist** | Downstream conforms to upstream's model |
| **Anti-Corruption Layer** | Downstream translates upstream's model to protect its own |
| **Published Language** | Shared language (events, schemas) for cross-context communication |
| **Open Host Service** | Context exposes a standard protocol/API |
| **Shared Kernel** | Two contexts share a small common model (use sparingly) |

## Tactical Patterns

### Aggregate Design Rules

1. Aggregates enforce invariants — a consistency boundary
2. Reference other aggregates by ID only, never by direct object reference
3. Keep aggregates small — prefer more smaller aggregates over fewer large ones
4. One transaction = one aggregate
5. Use domain events for cross-aggregate communication

### Pattern Templates

**Entity** — has identity, mutable state:
```
class Order { id: OrderId, status: OrderStatus, items: OrderItem[] }
```

**Value Object** — no identity, immutable, compared by value:
```
class Money { amount: number, currency: Currency }
```

**Domain Event** — something that happened in the domain:
```
interface OrderPlaced { orderId: string, items: Item[], timestamp: Date }
```

**Domain Service** — logic that doesn't belong to a single entity:
```
class PricingService { calculateDiscount(order, customer): Money }
```

**Repository** — collection-like interface for aggregate persistence:
```
interface OrderRepository { findById(id): Order, save(order): void }
```

## Event Storming

When modeling a domain, produce these artifacts:

1. **Domain Events** (orange) — things that happened: `OrderPlaced`, `PaymentReceived`
2. **Commands** (blue) — actions that trigger events: `PlaceOrder`, `ProcessPayment`
3. **Aggregates** (yellow) — consistency boundaries: `Order`, `Payment`
4. **Policies** (purple) — reactions to events: "When PaymentReceived, ship order"
5. **Read Models** (green) — query projections: `OrderSummary`, `CustomerDashboard`
6. **External Systems** (pink) — integrations: `PaymentGateway`, `EmailService`

## Ubiquitous Language

- Define a glossary of domain terms for the project
- Use these terms consistently in code, docs, and conversation
- Challenge terms that are ambiguous or overloaded
- Each bounded context may have its own dialect
