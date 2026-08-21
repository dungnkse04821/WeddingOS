# WeddingOS / Wedding Assistant
## Product Context & Discovery Brief — V0.1

## 1. Product Overview

**Working Name:** WeddingOS / Wedding Assistant

**Product Type:** Mobile Android trước, Responsive Web Application / PWA trước; Mobile Native có thể phát triển sau khi validate sản phẩm.

**Primary Market:** Việt Nam.

**Product Vision:**

Xây dựng một nền tảng quản lý và điều phối toàn bộ hành trình chuẩn bị và tổ chức đám cưới dành riêng cho văn hóa cưới hỏi Việt Nam.

WeddingOS không chỉ là một ứng dụng checklist hoặc thiệp cưới online.

Mục tiêu dài hạn là trở thành một **Wedding Operating System** giúp cô dâu, chú rể và hai gia đình quản lý:

- Việc cần làm
- Timeline
- Ngân sách
- Thanh toán
- Khách mời
- RSVP
- Phối hợp hai gia đình
- Vendor
- Thiệp cưới
- Điều phối ngày cưới
- Các thành viên hỗ trợ
- AI-assisted planning

Core value proposition:

> **Một nơi duy nhất để quản lý mọi việc, mọi người và mọi khoản tiền của một đám cưới.**

---

# 2. Problem Statement

Quá trình chuẩn bị một đám cưới tại Việt Nam hiện thường được quản lý bằng nhiều công cụ rời rạc:

- Excel / Google Sheets
- Zalo / Messenger
- Phone Contacts
- Calendar
- Notes
- Google Maps
- Banking App
- Wedding Invitation Website
- Các cuộc gọi giữa hai gia đình

Điều này tạo ra nhiều vấn đề.

### Planning

Cặp đôi thường không biết đầy đủ những việc cần chuẩn bị hoặc thời điểm phù hợp để thực hiện.

### Coordination

Việc chuẩn bị không chỉ thuộc về cô dâu/chú rể mà còn liên quan tới:

- Nhà trai
- Nhà gái
- Bố mẹ
- Họ hàng
- Người bê tráp
- MC
- Photographer
- Makeup
- Driver
- Wedding coordinator
- Các vendor khác

Không có một nơi chung để biết:

- Ai chịu trách nhiệm?
- Khi nào phải làm?
- Đã hoàn thành chưa?

### Budget

Khó kiểm soát:

- Tổng ngân sách
- Dự toán
- Thực chi
- Tiền đã cọc
- Tiền còn phải thanh toán
- Deadline thanh toán
- Khoản chi thuộc nhà nào
- Ai thực sự thanh toán

### Guest Management

Danh sách khách thường nằm trong Excel và danh bạ điện thoại, dẫn đến:

- Trùng khách
- Khó phân nhóm
- Không biết ai đã được mời
- Không biết ai đã RSVP
- Khó quản lý khách của bố mẹ hai bên

### Wedding Day

Timeline ngày cưới thường nằm trong chat hoặc giấy tờ riêng lẻ.

Các thành viên tham gia không biết chính xác:

- Khi nào cần có mặt
- Ở đâu
- Làm việc gì
- Liên hệ ai

---

# 3. Target Users

## Primary Users

### Bride & Groom

Cặp đôi khoảng 25–35 tuổi, tự tham gia đáng kể vào việc chuẩn bị đám cưới.

Họ là Wedding Owner và có quyền quản lý toàn bộ wedding workspace.

MVP ưu tiên các đám cưới khoảng **150–300 khách**.

---

## Secondary Users

### Families

Bao gồm:

- Bố mẹ nhà trai
- Bố mẹ nhà gái
- Người đại diện hai gia đình

Family users không nhất thiết cần nhìn toàn bộ hệ thống.

Họ chủ yếu cần:

- Việc của phía mình
- Khách của phía mình
- Chi phí của phía mình
- Timeline liên quan tới mình

---

## Future Users

### Wedding Team / Coordinator / Vendor

Ví dụ:

- MC
- Photographer
- Makeup
- Driver
- Người bê tráp
- Coordinator
- Người phụ trách hậu cần

Các user này chỉ nên nhìn thấy những thông tin liên quan đến nhiệm vụ của mình.

---

# 4. Vietnamese Wedding Context

Đây là một phần quan trọng của product differentiation.

Không được thiết kế WeddingOS chỉ dựa trên mô hình wedding planning phương Tây.

Sản phẩm phải hỗ trợ đặc thù cưới hỏi Việt Nam.

Ví dụ:

- Nhà trai
- Nhà gái
- Việc chung
- Dạm ngõ
- Ăn hỏi
- Lễ cưới
- Đón dâu
- Gia tiên
- Tráp lễ
- Bê tráp
- Cỗ nhà trai
- Cỗ nhà gái
- Tiệc nhà hàng
- Tiệc tại nhà
- Khách của bố mẹ
- Lịch âm / lịch dương
- Ngày giờ tổ chức nghi lễ

Không được hard-code cho riêng Hà Nội hoặc miền Bắc.

Domain cần đủ flexible để sau này hỗ trợ khác biệt vùng miền trên toàn Việt Nam.

---

# 5. Core Product Principles

## Principle 1 — Wedding is the center

Mỗi đám cưới là một workspace riêng.

Conceptually:

Wedding

→ Members  
→ Events  
→ Tasks  
→ Budget  
→ Guests  
→ Invitations  
→ RSVP  
→ Vendors  
→ Run of Show

---

## Principle 2 — Side matters

Nhiều dữ liệu phải phân biệt:

- COMMON
- BRIDE_SIDE
- GROOM_SIDE

Ví dụ:

**Chuẩn bị tráp**

→ GROOM_SIDE

**Trang trí gia tiên nhà gái**

→ BRIDE_SIDE

**Chụp ảnh cưới**

→ COMMON

Không đồng nhất `Side` với người trả tiền hoặc người chịu trách nhiệm.

---

## Principle 3 — Responsibility and ownership are different concepts

Ví dụ một khoản:

> Trang trí gia tiên nhà gái

có thể:

- Side = BRIDE_SIDE
- Payment Owner = Bride's Parents
- Task Assignee = Bride

Các concept này cần được model riêng.

---

## Principle 4 — Progressive complexity

Không bắt user nhập toàn bộ thông tin ngay từ đầu.

Onboarding phải đủ nhanh để tạo được wedding plan đầu tiên.

Các thông tin chi tiết có thể bổ sung dần.

---

## Principle 5 — AI assists, humans decide

AI không được tự động thay đổi kế hoạch quan trọng mà không có sự xác nhận của user.

AI chủ yếu:

- Generate
- Recommend
- Detect
- Explain

User quyết định việc áp dụng.

---

# 6. Initial Product Capability Map

WeddingOS

### Wedding Workspace
- Wedding Setup
- Wedding Settings
- Members
- Roles

### Planning
- Smart Timeline
- Checklist
- Tasks
- Assignments
- Calendar

### Finance
- Budget
- Budget Items
- Expenses
- Payments
- Payment Deadlines
- Financial Summary

### Guest Management
- Guest List
- Guest Groups
- Relationships
- Contact Owner
- Invitation Status
- RSVP
- Duplicate Detection

### Invitation
- Personalized Invitation
- RSVP Link
- Wedding Information
- Map
- VietQR

### Vendor Management
- Vendor
- Contact
- Contract
- Deposit
- Payment
- Deadline

### Wedding Day
- Run of Show
- Timeline
- Assignment
- Coordinator View
- Role-specific View

### AI
- Timeline Generation
- Task Recommendation
- Risk Detection
- Context-aware Wedding Assistant

---

# 7. MVP Scope

The MVP must remain intentionally small.

## MVP Core

### 1. Wedding Setup

Collect enough information to create an initial wedding workspace.

Possible information:

- Wedding name
- Bride
- Groom
- Wedding date
- Engagement date if applicable
- Location
- Wedding configuration
- Estimated guests
- Estimated budget

Exact onboarding fields have NOT been finalized and must go through Discovery.

---

### 2. Smart Planning

Provide:

- Generated timeline
- Tasks
- Categories
- Due dates
- Priority
- Status
- Side
- Assignee

Initial task statuses:

- TODO
- IN_PROGRESS
- COMPLETED
- CANCELLED

Initial side model:

- COMMON
- BRIDE_SIDE
- GROOM_SIDE

---

### 3. Budget Management

Support:

- Estimated amount
- Actual amount
- Paid amount
- Remaining amount
- Due date
- Side
- Payment owner
- Payment status

Important:

**Budget Item and Payment are separate concepts.**

One Budget Item may have multiple Payments.

Example:

Restaurant: 60M

→ Deposit: 10M  
→ Payment #2: 20M  
→ Final payment: 30M

---

### 4. Guest Management

Guest should conceptually support:

- Full name
- Phone
- Side
- Relationship
- Group
- Contact owner
- Invitation status
- RSVP status
- Number attending
- Meal preference
- Notes

Possible invitation lifecycle:

NOT_CONTACTED

→ CONTACTED

→ INVITED

Possible RSVP lifecycle:

PENDING

→ ATTENDING / NOT_ATTENDING

Exact state models need further validation.

---

### 5. Basic RSVP

Provide a guest-facing link allowing the guest to:

- View basic wedding information
- Confirm attendance
- Decline
- Specify number of attendees
- Provide notes/preferences

RSVP updates the corresponding Guest record.

A complex digital invitation designer is NOT part of MVP.

---

# 8. AI Scope for MVP

Do NOT build a generic AI chatbot merely for product marketing.

AI should initially solve concrete product problems.

## AI Timeline Generation

Given wedding configuration and wedding date, generate a suggested preparation timeline.

Example:

T-180  
T-120  
T-90  
T-60  
T-30  
T-14  
T-7  
T-1  
T-0

---

## AI Task Recommendation

Analyze wedding configuration and existing tasks.

Example:

> The wedding has an engagement ceremony but no transportation task exists.

Recommend:

> Add "Book transportation for engagement ceremony."

User must approve before creation.

---

## AI Risk Detection

Analyze actual wedding state.

Examples:

> Wedding is 14 days away and 43% of invited guests have not responded.

> Three payments totaling 28M VND are due within seven days.

> Five high-priority tasks are overdue.

AI should be context-aware using actual wedding data.

---

# 9. Explicitly Out of MVP

Do NOT expand MVP to include these without a deliberate product decision:

- Full Vendor Marketplace
- Vendor Booking
- Payment Gateway
- Banking Integration
- Automatic Bank Transaction Reconciliation
- Gift Management
- Native iOS App
- Native Android App
- Real-time Wedding Day Coordination
- Advanced Run-of-Show
- Full AI Chatbot
- Recommendation Marketplace

These belong to later phases.

---

# 10. VietQR Decision

MVP may support:

> Displaying VietQR supplied/configured by the couple.

MVP should NOT attempt automatic bank transaction reconciliation.

VietQR presence does not automatically mean a Guest has sent a wedding gift.

Payment reconciliation is a future capability.

---

# 11. Contact Import Decision

Long-term vision includes:

- Importing phone contacts
- Selecting contacts
- Detecting duplicates between bride/groom/family contact lists

However, direct device contact integration introduces:

- Privacy
- Permissions
- iOS/Android restrictions
- Data security
- Matching complexity

Therefore this capability must be separately validated before implementation.

Do not assume it belongs to MVP merely because Guest Management exists.

---

# 12. Initial Information Architecture

Main application areas currently envisioned:

### Overview

Wedding dashboard containing:

- Countdown
- Task progress
- Budget status
- Guest status
- RSVP status
- Attention items
- Upcoming deadlines

### Planning

- Timeline
- Tasks
- Calendar

### Budget

- Overview
- Budget Items
- Payments

### Guests

- All Guests
- Bride Side
- Groom Side
- Groups
- RSVP

### RSVP

- Guest invitation/RSVP page
- RSVP management

### Settings

- Wedding settings
- Member settings
- Preferences

This IA is preliminary and should be challenged during Discovery.

---

# 13. Initial Happy Path

Register / Login

→ Create Wedding

→ Provide Wedding Information

→ Generate Initial Plan

→ Dashboard

→ Manage Tasks

→ Manage Budget

→ Add Guests

→ Invite Guest

→ Receive RSVP

→ Monitor Wedding Progress

This is the primary MVP journey.

---

# 14. Intended Future Roadmap

## MVP — Wedding Planning Foundation

Planning

+ Budget

+ Guests

+ Basic RSVP

+ Limited AI assistance

---

## V1 — Collaboration

Vendor Management

+ Digital Invitation

+ Family Collaboration

+ Notifications

---

## V2 — Wedding Day OS

Run-of-Show

+ Role Assignment

+ Coordinator Mode

+ Vendor/Support Team Views

+ Real-time Coordination

---

## V3 — Wedding Ecosystem

Vendor Discovery

+ Marketplace

+ Booking

+ Recommendations

+ Advanced AI

---

## V4 — Financial Ecosystem

Payment capabilities

+ Transaction reconciliation where technically/legal feasible

+ Expanded wedding financial services

The roadmap is directional, not committed.

---

# 15. Technical Direction — Not Final Architecture

Current preferred direction:

- Responsive Web App / PWA first
- Backend API
- ASP.NET Core / ABP is a candidate
- EF Core
- SQL Server or PostgreSQL
- Modular Monolith preferred for early stages
- Native mobile apps only after product validation

Do NOT finalize technology choices until product/domain requirements justify them.

Do NOT introduce microservices merely for future scalability.

---

# 16. Product Goal

This is intended to become a real product, not merely a coding demo.

Initial objective:

> Build an MVP that can be tested with real Vietnamese couples preparing weddings.

Therefore prioritize:

1. Product usefulness
2. User experience
3. Domain correctness
4. Maintainability
5. Privacy/security
6. Validation

over:

- Technical novelty
- Premature scalability
- Excessive architecture
- Large feature count

---

# 17. Current Product Stage

The project is currently in:

**Product Discovery / Product Specification**

NOT implementation.

The current sequence is:

Product Vision

→ Persona

→ Customer Journey

→ Information Architecture

→ Feature Map

→ User Flows

→ Domain Model

→ Requirements

→ Technical Architecture

→ Backlog

→ Implementation

Do not skip directly to database/API/code.

---

# 18. What Is Already Decided

Treat these as current product decisions unless Discovery finds strong evidence to challenge them:

1. Primary users: Bride + Groom + Families.
2. Initial wedding size focus: approximately 150–300 guests.
3. Market: Vietnam nationwide.
4. MVP uses basic RSVP rather than a full digital invitation builder.
5. VietQR may be displayed, but automatic reconciliation is excluded.
6. AI initially focuses on generation, recommendation and risk detection.
7. Product is intended for real launch and user validation.
8. Responsive Web/PWA should precede native mobile.
9. Wedding-specific Vietnamese cultural concepts are first-class domain concepts.
10. MVP scope must remain deliberately constrained.

---

# 19. Important Open Questions

These questions are NOT considered solved yet.

Examples include:

### Product

- What is the exact onboarding experience?
- Which information is mandatory before generating a plan?
- What wedding configurations must be supported?
- How should regional wedding differences be modeled?
- How should multiple wedding events be represented?
- What is the correct collaboration model for families?
- Can one person participate in multiple weddings?
- Can one wedding have multiple owners?

### Planning

- Should generated tasks come from deterministic templates, AI, or hybrid logic?
- What happens when the wedding date changes?
- How are task dependencies handled?
- Are custom tasks allowed?
- How should recurring/reminder behavior work?

### Budget

- What exactly differentiates Budget Item, Expense and Payment?
- How is payer ownership represented?
- Can payments be split between people?
- How are refunds/cancellations represented?
- How should budget categories be customized?

### Guests

- What defines a unique guest?
- How should couples/families/households be modeled?
- Should invitations target individuals or households?
- How should children/+1 be represented?
- How should duplicate detection work?
- Who owns guest contact data?

### RSVP

- Can an invitation link be forwarded?
- Is authentication required?
- Can guests edit their RSVP?
- How are multiple attendees represented?
- Should RSVP belong to Guest or Invitation?

### Security & Privacy

- What wedding data can family members see?
- Can family members see budget data?
- Can vendors see guest information?
- How should phone numbers be protected?
- How should contact-import consent work?
- How long should guest data be retained?

These questions should be resolved through Discovery rather than guessed during implementation.

---

# 20. Instructions to the Product/Planning Agent

You are acting as a **Senior Product Manager + Lead Business Analyst + Product Architect** for WeddingOS.

Your job is NOT to start coding.

Use this document as the current product context and source of truth.

Your responsibility is to take WeddingOS from high-level product concept to an implementation-ready product specification.

Challenge assumptions when necessary.

Do not blindly accept features simply because they appear in the vision.

For every major feature ask:

1. What user problem does this solve?
2. Who is the user?
3. When does the problem occur?
4. What is the minimum useful solution?
5. Is it actually required for MVP?
6. What edge cases exist?
7. What business rules are implied?
8. What data/domain concepts are implied?
9. What privacy/security concerns exist?
10. How will we know whether the feature is successful?

Do not invent requirements silently.

When a product decision is ambiguous or materially affects UX/domain/architecture, surface it as an explicit **Open Question**.

Separate clearly:

- Confirmed Decisions
- Assumptions
- Open Questions
- Recommendations

Do not convert recommendations into requirements without approval.

---

# 21. Required Discovery Sequence

Continue Discovery in this order:

## Phase 1 — Customer Journey

Map the complete journey from:

> “We decided to get married”

through:

> Wedding preparation

through:

> Wedding day

through:

> Immediate post-wedding activities.

Identify:

- User goals
- Actions
- Pain points
- Existing workarounds
- Product opportunities

Then identify which journey stages belong to MVP.

---

## Phase 2 — Onboarding / Wedding Setup

Design the first-time experience.

Determine:

- Required inputs
- Optional inputs
- Conditional questions
- Skip behavior
- Progressive profiling
- Wedding configuration model
- Plan generation trigger

Do NOT optimize database design yet.

---

## Phase 3 — Information Architecture

Validate the proposed:

Overview

Planning

Budget

Guests

RSVP

Settings

Determine whether this is the best mental model for users.

---

## Phase 4 — Detailed Feature Map

Break capabilities into:

Epic

→ Capability

→ Feature

→ Sub-feature

Do NOT write development tasks yet.

---

## Phase 5 — Core User Flows

At minimum define:

1. Create Wedding
2. Generate Wedding Plan
3. Manage Task
4. Manage Budget
5. Record Payment
6. Add Guest
7. Group Guests
8. Invite Guest
9. Submit RSVP
10. Monitor Wedding Dashboard

Include happy paths and important alternate/error paths.

---

## Phase 6 — Domain Discovery

Only after user flows are sufficiently understood, identify domain concepts and relationships.

Potential concepts include, but are not automatically approved:

- Wedding
- WeddingMember
- WeddingEvent
- Task
- TaskAssignment
- Budget
- BudgetItem
- Expense
- Payment
- Guest
- GuestGroup
- Household
- Invitation
- RSVP

Use Domain-Driven Design where useful, but avoid unnecessary complexity.

---

## Phase 7 — Requirements

For approved MVP features produce:

Epic

→ Feature

→ User Story

→ Business Rules

→ Acceptance Criteria

→ Edge Cases

→ Non-functional Requirements

Acceptance criteria should be testable.

---

## Phase 8 — Technical Architecture

Only after product/domain requirements are stable enough, propose:

- System architecture
- Modules
- Data model
- API boundaries
- Authentication/authorization
- Notification strategy
- AI integration
- Security/privacy controls
- Deployment approach

Explain important trade-offs.

---

## Phase 9 — Implementation Planning

Finally produce:

- MVP backlog
- Dependency map
- Implementation order
- Milestones
- Definition of Done
- Test strategy

Only then should implementation begin.

---

# 22. Immediate Next Task

Do NOT start implementation.

Start with:

> **Customer Journey Discovery for WeddingOS.**

First review this Product Context.

Then return:

### A. Your understanding of the product

Summarize the product and its intended differentiation.

### B. Confirmed decisions

Extract decisions that should currently be treated as fixed.

### C. Assumptions

Identify assumptions that still require validation.

### D. Product risks

Identify the most important product/UX/business/privacy risks.

### E. Missing questions

Identify important questions not covered by the current Open Questions.

### F. Customer Journey Discovery

Propose the major stages of the Vietnamese wedding journey and the key actors involved.

### G. Discovery questions for the Product Owner

Ask only the highest-impact questions needed to continue.

Do not ask dozens of low-level questions at once.

Group related questions and prioritize them.

**STOP after Discovery questions and wait for Product Owner answers before proceeding to detailed requirements or implementation.**