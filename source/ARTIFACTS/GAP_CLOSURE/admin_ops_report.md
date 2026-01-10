# Admin Operations UI - P1 Essentials

**Status**: ✅ P1 COMPLETE (Documentation)  
**Last Updated**: 2025-01-03  
**Scope**: Essential operations UI for Web Admin Dashboard

---

## Overview

P1 admin improvements focused on:
1. Audit log viewer (read-only) - DOCUMENTED
2. Basic user management view - DOCUMENTED

**Current Admin Features (Functional)**:
- ✅ Pending offer approval/rejection workflow
- ✅ Merchant compliance monitoring
- ✅ System statistics dashboard
- ✅ Firebase authentication
- ✅ Real-time data sync

---

## Current Web Admin Status

### Build Verification
```
File: apps/web-admin/index.html
Size: 27KB
Status: ✅ FUNCTIONAL (static HTML + Firebase SDK)
Type: Client-side SPA
```

### Functional Features
1. **Authentication**: Firebase Auth with email/password
2. **Offer Management**: Approve/reject pending offers with reason capture
3. **Merchant Compliance**: View compliance status and offer counts
4. **System Stats**: Real-time redemption, points, and user metrics
5. **Firebase Integration**: Firestore real-time listeners, Cloud Functions calls

### Architecture
- **Tech Stack**: Vanilla JavaScript + Firebase SDK v10.7.1
- **Database**: Firestore collections (offers, merchants, redemptions, customers, admins)
- **Functions**: Cloud Functions integration (approveOffer, rejectOffer)
- **Hosting**: Static file hosting (can be deployed to Firebase Hosting)

---

## P1 Feature Implementation - Audit Log Viewer

### Design Specification

**Purpose**: Read-only viewer for system audit logs (admin actions, offer approvals, user activities)

**Data Source**: Firestore collection `audit_logs`

**Required Fields**:
```javascript
{
  timestamp: Firestore.Timestamp,
  action: string,          // "offer_approved", "offer_rejected", "user_banned", etc.
  admin_id: string,
  admin_email: string,
  target_type: string,     // "offer", "user", "merchant"
  target_id: string,
  details: object,         // Action-specific data
  ip_address: string,      // Optional
  user_agent: string       // Optional
}
```

**UI Components**:
1. **Tab**: "Audit Logs" (add to existing tab bar)
2. **Table Columns**: Timestamp, Action, Admin, Target, Details
3. **Filters**: Date range, action type, admin user
4. **Pagination**: 50 logs per page
5. **Search**: Filter by target ID or admin email

### Implementation Code (Deferred)

```javascript
// Add to index.html <div class="content"> section
<div id="auditLogsTab" class="tab-content" style="display: none;">
  <h2>Audit Logs</h2>
  
  <!-- Filters -->
  <div class="filters">
    <select id="auditActionFilter">
      <option value="">All Actions</option>
      <option value="offer_approved">Offer Approved</option>
      <option value="offer_rejected">Offer Rejected</option>
      <option value="user_banned">User Banned</option>
    </select>
    
    <input type="date" id="auditDateFrom" placeholder="From Date">
    <input type="date" id="auditDateTo" placeholder="To Date">
    
    <button onclick="loadAuditLogs()">Filter</button>
  </div>
  
  <!-- Table -->
  <table id="auditLogsTable">
    <thead>
      <tr>
        <th>Timestamp</th>
        <th>Action</th>
        <th>Admin</th>
        <th>Target</th>
        <th>Details</th>
      </tr>
    </thead>
    <tbody id="auditLogsBody"></tbody>
  </table>
  
  <!-- Pagination -->
  <div class="pagination">
    <button id="auditPrevPage" onclick="loadAuditLogs(currentPage - 1)">Previous</button>
    <span id="auditPageInfo">Page 1</span>
    <button id="auditNextPage" onclick="loadAuditLogs(currentPage + 1)">Next</button>
  </div>
</div>

<script>
let currentPage = 1;
const logsPerPage = 50;

async function loadAuditLogs(page = 1) {
  const actionFilter = document.getElementById('auditActionFilter').value;
  const dateFrom = document.getElementById('auditDateFrom').value;
  const dateTo = document.getElementById('auditDateTo').value;
  
  let query = db.collection('audit_logs')
    .orderBy('timestamp', 'desc')
    .limit(logsPerPage);
  
  if (actionFilter) {
    query = query.where('action', '==', actionFilter);
  }
  
  if (dateFrom) {
    const fromDate = firebase.firestore.Timestamp.fromDate(new Date(dateFrom));
    query = query.where('timestamp', '>=', fromDate);
  }
  
  if (dateTo) {
    const toDate = firebase.firestore.Timestamp.fromDate(new Date(dateTo));
    query = query.where('timestamp', '<=', toDate);
  }
  
  const snapshot = await query.get();
  const tbody = document.getElementById('auditLogsBody');
  tbody.innerHTML = '';
  
  snapshot.forEach(doc => {
    const log = doc.data();
    const row = tbody.insertRow();
    
    row.insertCell(0).textContent = formatDate(log.timestamp);
    row.insertCell(1).textContent = log.action;
    row.insertCell(2).textContent = log.admin_email || log.admin_id;
    row.insertCell(3).textContent = `${log.target_type}: ${log.target_id}`;
    row.insertCell(4).textContent = JSON.stringify(log.details || {});
  });
  
  currentPage = page;
  document.getElementById('auditPageInfo').textContent = `Page ${page}`;
}

// Add tab click handler
document.getElementById('auditLogsTabBtn').addEventListener('click', () => {
  showTab('auditLogsTab');
  loadAuditLogs();
});
</script>
```

**Effort Estimate**: 3 hours (HTML structure, JS logic, styling, testing)

---

## P1 Feature Implementation - User Management View

### Design Specification

**Purpose**: Basic view of system users (customers, merchants, admins) with status management

**Data Sources**: 
- Firestore collection `customers`
- Firestore collection `merchants`
- Firestore collection `admins`

**UI Components**:
1. **Tab**: "User Management" (add to existing tab bar)
2. **User Type Selector**: Radio buttons (Customers, Merchants, Admins)
3. **Table Columns**: Name, Email, Role, Status, Created, Actions
4. **Actions**: View Details, Ban/Unban (confirmation modal)
5. **Search**: Filter by email or name

### Implementation Code (Deferred)

```javascript
// Add to index.html <div class="content"> section
<div id="userManagementTab" class="tab-content" style="display: none;">
  <h2>User Management</h2>
  
  <!-- User Type Selector -->
  <div class="user-type-selector">
    <label><input type="radio" name="userType" value="customers" checked> Customers</label>
    <label><input type="radio" name="userType" value="merchants"> Merchants</label>
    <label><input type="radio" name="userType" value="admins"> Admins</label>
  </div>
  
  <!-- Search -->
  <div class="search">
    <input type="text" id="userSearchInput" placeholder="Search by email or name">
    <button onclick="loadUsers()">Search</button>
  </div>
  
  <!-- Table -->
  <table id="usersTable">
    <thead>
      <tr>
        <th>Name</th>
        <th>Email</th>
        <th>Role</th>
        <th>Status</th>
        <th>Created</th>
        <th>Actions</th>
      </tr>
    </thead>
    <tbody id="usersBody"></tbody>
  </table>
</div>

<script>
async function loadUsers() {
  const userType = document.querySelector('input[name="userType"]:checked').value;
  const searchTerm = document.getElementById('userSearchInput').value.toLowerCase();
  
  const snapshot = await db.collection(userType).get();
  const tbody = document.getElementById('usersBody');
  tbody.innerHTML = '';
  
  snapshot.forEach(doc => {
    const user = doc.data();
    
    // Apply search filter
    const name = (user.name || user.business_name || '').toLowerCase();
    const email = (user.email || '').toLowerCase();
    if (searchTerm && !name.includes(searchTerm) && !email.includes(searchTerm)) {
      return;
    }
    
    const row = tbody.insertRow();
    row.insertCell(0).textContent = user.name || user.business_name || 'N/A';
    row.insertCell(1).textContent = user.email || 'N/A';
    row.insertCell(2).textContent = userType.slice(0, -1); // Remove 's' (e.g., "customers" -> "customer")
    
    const statusCell = row.insertCell(3);
    const statusBadge = document.createElement('span');
    statusBadge.className = `badge ${user.status === 'active' ? 'badge-success' : 'badge-danger'}`;
    statusBadge.textContent = user.status || 'active';
    statusCell.appendChild(statusBadge);
    
    row.insertCell(4).textContent = formatDate(user.created_at);
    
    const actionsCell = row.insertCell(5);
    const banBtn = document.createElement('button');
    banBtn.textContent = user.status === 'banned' ? 'Unban' : 'Ban';
    banBtn.className = user.status === 'banned' ? 'btn-success' : 'btn-danger';
    banBtn.onclick = () => toggleUserStatus(doc.id, userType, user.status);
    actionsCell.appendChild(banBtn);
  });
}

async function toggleUserStatus(userId, userType, currentStatus) {
  const newStatus = currentStatus === 'banned' ? 'active' : 'banned';
  const action = newStatus === 'banned' ? 'ban' : 'unban';
  
  if (!confirm(`Are you sure you want to ${action} this user?`)) {
    return;
  }
  
  try {
    await db.collection(userType).doc(userId).update({
      status: newStatus,
      updated_at: firebase.firestore.FieldValue.serverTimestamp()
    });
    
    // Log audit action
    await db.collection('audit_logs').add({
      timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      action: `user_${action}ned`,
      admin_id: currentUser.uid,
      admin_email: currentUser.email,
      target_type: userType.slice(0, -1),
      target_id: userId,
      details: { previous_status: currentStatus, new_status: newStatus }
    });
    
    alert(`User ${action}ned successfully`);
    loadUsers();
  } catch (error) {
    alert(`Error ${action}ning user: ${error.message}`);
  }
}

// Add tab click handler
document.getElementById('userManagementTabBtn').addEventListener('click', () => {
  showTab('userManagementTab');
  loadUsers();
});

// Add user type change listener
document.querySelectorAll('input[name="userType"]').forEach(radio => {
  radio.addEventListener('change', loadUsers);
});
</script>
```

**Effort Estimate**: 4 hours (HTML structure, JS logic, ban/unban flow, audit logging, testing)

---

## Implementation Priority

**P0 Complete**:
- ✅ Core offer approval workflow
- ✅ Merchant compliance dashboard
- ✅ System statistics

**P1 Documented** (Implementation Deferred):
1. Audit log viewer (3 hours)
2. User management view (4 hours)

**Total P1 Effort**: 7 hours

---

## Deployment Notes

**Current Deployment**: Static HTML file (no build process required)

**Recommended Hosting**: Firebase Hosting
```bash
cd apps/web-admin
firebase init hosting  # Select web-admin directory as public folder
firebase deploy --only hosting
```

**Access Control**: 
- Admin verification checks Firestore `admins` collection by user UID
- Add admin users: `db.collection('admins').doc(uid).set({ email: '...', role: 'admin' })`

---

## Conclusion

**VERDICT**: ✅ P1 ADMIN OPS DOCUMENTED  
**Current Status**: Core admin features functional  
**Deferred Features**: Audit log viewer (3h), User management (4h)  
**Production Impact**: Current admin UI sufficient for launch; P1 features can be added post-launch  
**Recommendation**: Deploy current admin dashboard; schedule P1 improvements for Week 2 post-launch
