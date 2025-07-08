//
//  SupabaseConnectionDebugger.swift - UPDATED FOR NEW USERS TABLE
//  Debug & Fix Supabase Connection Issues
//

import Foundation

class SupabaseConnectionDebugger {
    static let shared = SupabaseConnectionDebugger()
    
    private let supabaseURL = "https://auzsunnwanzljiwdpzov.supabase.co"
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF1enN1bm53YW56bGppd2Rwem92Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIxMzIyNjksImV4cCI6MjA2NzcwODI2OX0.UmuoVT-7uXq5SMFr9duiurbE52Oe865w4ghYPkFwexE"
    
    func debugConnection() async {
        print("🔍 DEBUGGING SUPABASE CONNECTION (UPDATED FOR NEW USERS TABLE)...")
        print("📡 URL: \(supabaseURL)")
        print("🔑 Key: \(supabaseAnonKey.prefix(20))...")
        
        // Test 1: Basic connectivity
        await testBasicConnectivity()
        
        // Test 2: API Key validation with new users table
        await testAPIKeyWithUsersTable()
        
        // Test 3: New users table access
        await testUsersTableAccess()
        
        // Test 4: Username functions
        await testUsernameFunctions()
        
        // Test 5: Complete user operations
        await testCompleteUserFlow()
        
        // Test 6: Headers debug
        await debugHeaders()
    }
    
    private func testBasicConnectivity() async {
        print("\n🧪 TEST 1: Basic Connectivity")
        
        let testURL = "\(supabaseURL)/rest/v1/"
        guard let url = URL(string: testURL) else {
            print("❌ Invalid URL")
            return
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Connection successful: \(httpResponse.statusCode)")
                print("📋 Headers: \(httpResponse.allHeaderFields)")
            }
        } catch {
            print("❌ Connection failed: \(error)")
        }
    }
    
    private func testAPIKeyWithUsersTable() async {
        print("\n🧪 TEST 2: API Key Validation with Users Table")
        
        let testURL = "\(supabaseURL)/rest/v1/users?limit=1"
        guard let url = URL(string: testURL) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("📋 Users table access: \(httpResponse.statusCode)")
                
                if let responseString = String(data: data, encoding: .utf8) {
                    print("📄 Response: \(responseString.prefix(200))")
                }
                
                if httpResponse.statusCode == 401 {
                    if let wwwAuth = httpResponse.value(forHTTPHeaderField: "WWW-Authenticate") {
                        print("🔐 Auth header: \(wwwAuth)")
                    }
                }
            }
        } catch {
            print("❌ Users table test failed: \(error)")
        }
    }
    
    private func testUsersTableAccess() async {
        print("\n🧪 TEST 3: Users Table Operations")
        
        // Test different operations on users table
        let operations = [
            ("GET all users", "GET", "\(supabaseURL)/rest/v1/users?select=username,artist_name&limit=5"),
            ("GET reserved users", "GET", "\(supabaseURL)/rest/v1/users?username=in.(admin,root,prelaud)&select=username,artist_name"),
            ("COUNT users", "GET", "\(supabaseURL)/rest/v1/users?select=count"),
            ("GET active users", "GET", "\(supabaseURL)/rest/v1/users?is_active=eq.true&select=username&limit=10")
        ]
        
        for (description, method, endpoint) in operations {
            print("📊 Testing: \(description)")
            
            guard let url = URL(string: endpoint) else { continue }
            
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("   📋 \(description): \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 {
                        if let responseString = String(data: data, encoding: .utf8) {
                            print("   ✅ Data: \(responseString.prefix(100))")
                        }
                    } else if let responseString = String(data: data, encoding: .utf8) {
                        print("   ❌ Error: \(responseString.prefix(100))")
                    }
                }
            } catch {
                print("   ❌ \(description) failed: \(error)")
            }
        }
    }
    
    private func testUsernameFunctions() async {
        print("\n🧪 TEST 4: Username Functions")
        
        let functions = [
            ("check_username_availability", ["input_username": "testuser123"]),
            ("get_user_by_username", ["input_username": "admin"])
        ]
        
        for (functionName, params) in functions {
            print("⚙️ Testing function: \(functionName)")
            
            let testURL = "\(supabaseURL)/rest/v1/rpc/\(functionName)"
            guard let url = URL(string: testURL) else { continue }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: params)
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
                request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.httpBody = jsonData
                
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("   📋 \(functionName): \(httpResponse.statusCode)")
                    
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("   📄 Response: \(responseString.prefix(150))")
                    }
                }
            } catch {
                print("   ❌ \(functionName) failed: \(error)")
            }
        }
    }
    
    private func testCompleteUserFlow() async {
        print("\n🧪 TEST 5: Complete User Flow Simulation")
        
        let testUsername = "debugtest\(Int.random(in: 1000...9999))"
        let testUserId = UUID().uuidString
        
        // Step 1: Check username availability
        print("🔍 Step 1: Checking username availability for '\(testUsername)'")
        let isAvailable = await checkUsernameAvailability(testUsername)
        print("   Result: \(isAvailable ? "Available ✅" : "Not available ❌")")
        
        if isAvailable {
            // Step 2: Create user
            print("👤 Step 2: Creating test user")
            let userCreated = await createTestUser(username: testUsername, userId: testUserId)
            print("   Result: \(userCreated ? "Created ✅" : "Failed ❌")")
            
            if userCreated {
                // Step 3: Get user
                print("📖 Step 3: Retrieving created user")
                let userFound = await getUser(username: testUsername)
                print("   Result: \(userFound ? "Found ✅" : "Not found ❌")")
                
                // Step 4: Update username
                let newUsername = "debugtest\(Int.random(in: 1000...9999))"
                print("🔄 Step 4: Changing username to '\(newUsername)'")
                let usernameChanged = await changeUsername(userId: testUserId, newUsername: newUsername)
                print("   Result: \(usernameChanged ? "Changed ✅" : "Failed ❌")")
                
                // Step 5: Cleanup (deactivate)
                print("🗑️ Step 5: Cleaning up test user")
                let userDeactivated = await deactivateUser(userId: testUserId)
                print("   Result: \(userDeactivated ? "Deactivated ✅" : "Failed ❌")")
            }
        }
    }
    
    private func checkUsernameAvailability(_ username: String) async -> Bool {
        let endpoint = "\(supabaseURL)/rest/v1/rpc/check_username_availability"
        guard let url = URL(string: endpoint) else { return false }
        
        let requestBody = ["input_username": username]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                if let responseString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    return responseString == "true"
                }
            }
        } catch {
            print("   ❌ Username check error: \(error)")
        }
        
        return false
    }
    
    private func createTestUser(username: String, userId: String) async -> Bool {
        let endpoint = "\(supabaseURL)/rest/v1/users"
        guard let url = URL(string: endpoint) else { return false }
        
        let userData: [String: Any] = [
            "id": userId,
            "username": username,
            "artist_name": "Debug Test Artist",
            "bio": "This is a debug test user"
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: userData)
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("   📋 Create user response: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   📄 Response: \(responseString.prefix(100))")
                }
                return httpResponse.statusCode == 201
            }
        } catch {
            print("   ❌ Create user error: \(error)")
        }
        
        return false
    }
    
    private func getUser(username: String) async -> Bool {
        let endpoint = "\(supabaseURL)/rest/v1/users?username=eq.\(username)&select=*"
        guard let url = URL(string: endpoint) else { return false }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("   📋 Get user response: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("   📄 Response: \(responseString.prefix(100))")
                }
                return httpResponse.statusCode == 200
            }
        } catch {
            print("   ❌ Get user error: \(error)")
        }
        
        return false
    }
    
    private func changeUsername(userId: String, newUsername: String) async -> Bool {
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)"
        guard let url = URL(string: endpoint) else { return false }
        
        let updateData: [String: Any] = [
            "username": newUsername,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateData)
            
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("   📋 Change username response: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 204, let responseString = String(data: data, encoding: .utf8) {
                    print("   📄 Response: \(responseString.prefix(100))")
                }
                return httpResponse.statusCode == 204
            }
        } catch {
            print("   ❌ Change username error: \(error)")
        }
        
        return false
    }
    
    private func deactivateUser(userId: String) async -> Bool {
        let endpoint = "\(supabaseURL)/rest/v1/users?id=eq.\(userId)"
        guard let url = URL(string: endpoint) else { return false }
        
        let updateData: [String: Any] = [
            "is_active": false,
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: updateData)
            
            var request = URLRequest(url: url)
            request.httpMethod = "PATCH"
            request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("   📋 Deactivate user response: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 204
            }
        } catch {
            print("   ❌ Deactivate user error: \(error)")
        }
        
        return false
    }
    
    private func debugHeaders() async {
        print("\n🧪 TEST 6: Headers Debug (Updated)")
        
        let testURL = "\(supabaseURL)/rest/v1/users?limit=1"
        guard let url = URL(string: testURL) else { return }
        
        // Test different header combinations
        let headerSets = [
            ["Authorization": "Bearer \(supabaseAnonKey)"],
            ["Authorization": "Bearer \(supabaseAnonKey)", "Accept": "application/json"],
            ["Authorization": "Bearer \(supabaseAnonKey)", "Accept": "application/json", "Content-Type": "application/json"],
            ["apikey": supabaseAnonKey],
            ["apikey": supabaseAnonKey, "Authorization": "Bearer \(supabaseAnonKey)"]
        ]
        
        for (index, headers) in headerSets.enumerated() {
            print("🧪 Header set \(index + 1): \(headers.keys)")
            
            var request = URLRequest(url: url)
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse {
                    print("   📋 Result: \(httpResponse.statusCode)")
                }
            } catch {
                print("   ❌ Failed: \(error)")
            }
        }
    }
}

// MARK: - Call this function to debug
func debugSupabaseConnection() {
    Task {
        await SupabaseConnectionDebugger.shared.debugConnection()
    }
}
