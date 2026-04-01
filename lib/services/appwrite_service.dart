import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart';
import 'package:appwrite/enums.dart';
import 'package:myapp/config/env.dart'; 

class AppwriteService extends ChangeNotifier {
  late Client client;
  late Account account;
  late Databases databases;
  late Avatars avatars;

  AppwriteService() {
    client = Client()
      ..setEndpoint(Env.appwriteEndpoint)   
      ..setProject(Env.appwriteProjectId);

    account = Account(client);
    databases = Databases(client);
    avatars = Avatars(client);
  }

  // =========================================================================
  // AUTHENTICATION METHODS
  // =========================================================================

  Future<User?> getCurrentUser() async {
    try {
      return await account.get();
    } catch (e) {
      debugPrint("No active session or error: $e");
      return null;
    }
  }
  
  Future<Session?> loginEmailPassword(String email, String password) async {
     try {
       final session = await account.createEmailPasswordSession(email: email, password: password);
       notifyListeners();
       return session;
     } catch(e) {
       debugPrint("Login error: $e");
       rethrow;
     }
  }

  Future<bool> loginWithGoogle() async {
    try {
      await account.createOAuth2Session(provider: OAuthProvider.google);
      notifyListeners();
      return true; 
    } catch (e) {
      debugPrint("Google login error: $e");
      return false; 
    }
  }

  Future<User> registerEmailPassword(String email, String password, String name) async {
     try {
       final user = await account.create(
         userId: ID.unique(), 
         email: email, 
         password: password, 
         name: name
       );
       return user;
     } catch(e) {
       debugPrint("Register error: $e");
       rethrow;
     }
  }

  Future<void> logout() async {
     try {
       await account.deleteSession(sessionId: 'current');
       notifyListeners();
     } catch(e) {
       debugPrint("Logout error: $e");
     }
  }

  Future<Uint8List?> getUserAvatar(String name) async {
    try {
      return await avatars.getInitials(name: name);
    } catch (e) {
      debugPrint("Avatar error: $e");
      return null;
    }
  }

  // =========================================================================
  // 👔 WARDROBE (OUTFITS) DB METHODS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getWardrobeItems() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.outfitsCollection, 
        queries: [
          // 🛑 AS REQUESTED: Kept user_id ONLY for the Wardrobe/Outfits table
          Query.equal('user_id', user.$id), 
          Query.orderDesc('\$createdAt'), 
        ],
      );

      return result.documents.map((doc) {
        return {
          "id": doc.$id,
          "name": doc.data['name'],
          "category": doc.data['category'],
          "sub_category": doc.data['sub_category'],
          "color_code": doc.data['color_code'],
          "pattern": doc.data['pattern'],
          "occasions": doc.data['occasions'],
          "image_url": doc.data['image_url'], 
        };
      }).toList();

    } catch (e) {
      debugPrint("👕 Error fetching wardrobe items: $e");
      return []; 
    }
  }

  // =========================================================================
  // CALENDAR PLANS DB METHODS
  // =========================================================================

  Future<Document> createPlan(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating plan: $e");
      rethrow;
    }
  }

  Future<List<Document>> getUserPlans() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching plans: $e");
      return [];
    }
  }

  Future<void> deletePlan(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting plan: $e");
      rethrow;
    }
  }

  Future<void> updatePlanReminder(String documentId, bool reminder) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.plansCollection,
        documentId: documentId,
        data: {'reminder': reminder},
      );
    } catch (e) {
      debugPrint("Error updating plan reminder: $e");
      rethrow;
    }
  }

  // =========================================================================
  // SAVED BOARDS DB METHODS
  // =========================================================================

  Future<List<Document>> getSavedBoardsByOccasion(String occasion) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.equal('occasion', occasion),
          Query.orderDesc('\$createdAt'), 
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching $occasion boards: $e");
      return []; 
    }
  }

  Future<List<Document>> getAllSavedBoards() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'), 
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching all boards: $e");
      return []; 
    }
  }

  Future<void> deleteSavedBoard(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.savedBoardsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting board: $e");
      throw Exception("Failed to delete board");
    }
  }

  // =========================================================================
  // SKINCARE DB METHODS
  // =========================================================================

  Future<Document?> getSkincareProfile() async {
    try {
      final user = await getCurrentUser();
      if (user == null) return null;

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.skincareCollection,
        queries: [Query.equal('userId', user.$id)], // FIXED to userId
      );

      if (result.documents.isEmpty) {
        return await databases.createDocument(
          databaseId: Env.appwriteDatabaseId,
          collectionId: Env.skincareCollection,
          documentId: ID.unique(),
          data: {
            'userId': user.$id, // FIXED to userId
            'skinType': '',
            'concerns': [],
            'daySteps': [],
            'nightSteps': [],
            'lastUpdated': DateTime.now().toIso8601String(),
          },
        );
      }
      return result.documents.first;
    } catch (e) {
      debugPrint("Error fetching skincare profile: $e");
      return null;
    }
  }

  Future<void> updateSkincareProfile({
    required String documentId,
    String? skinType,
    List<String>? concerns,
    List<int>? daySteps,
    List<int>? nightSteps,
  }) async {
    try {
      Map<String, dynamic> updateData = {};
      if (skinType != null) updateData['skinType'] = skinType;
      if (concerns != null) updateData['concerns'] = concerns;
      if (daySteps != null) updateData['daySteps'] = daySteps;
      if (nightSteps != null) updateData['nightSteps'] = nightSteps;
      updateData['lastUpdated'] = DateTime.now().toIso8601String();

      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.skincareCollection,
        documentId: documentId,
        data: updateData,
      );
    } catch (e) {
      debugPrint("Error updating skincare profile: $e");
    }
  }

  // =========================================================================
  // WORKOUT OUTFITS DB METHODS
  // =========================================================================

  Future<List<Document>> getWorkoutOutfits() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching workout outfits: $e");
      return [];
    }
  }

  Future<Document> createWorkoutOutfit(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating workout outfit: $e");
      rethrow;
    }
  }

  Future<void> deleteWorkoutOutfit(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.workoutOutfitsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting workout outfit: $e");
      rethrow;
    }
  }

  // =========================================================================
  // BILLS & COUPONS DB METHODS
  // =========================================================================

  Future<List<Document>> getBills() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching bills: $e");
      return [];
    }
  }

  Future<Document> createBill(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating bill: $e");
      rethrow;
    }
  }

  Future<void> deleteBill(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.billsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting bill: $e");
      rethrow;
    }
  }

  Future<List<Document>> getCoupons() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
      return [];
    }
  }

  Future<Document> createCoupon(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating coupon: $e");
      rethrow;
    }
  }

  Future<void> deleteCoupon(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.couponsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting coupon: $e");
      rethrow;
    }
  }

  // =========================================================================
  // MEDI TRACKER DB METHODS
  // =========================================================================

  Future<List<Document>> getMeds() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching meds: $e");
      return [];
    }
  }

  Future<Document> createMed(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating med: $e");
      rethrow;
    }
  }

  Future<void> updateMed(String documentId, Map<String, dynamic> data) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: documentId,
        data: data,
      );
    } catch (e) {
      debugPrint("Error updating med: $e");
      rethrow;
    }
  }

  Future<void> deleteMed(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting med: $e");
      rethrow;
    }
  }

  Future<List<Document>> getMedLogs() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('time'), 
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching med logs: $e");
      return [];
    }
  }

  Future<Document> createMedLog(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.medLogsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating med log: $e");
      rethrow;
    }
  }

  // =========================================================================
  // MEAL PLANNER DB METHODS
  // =========================================================================

  Future<List<Document>> getMealPlans() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching meal plans: $e");
      return [];
    }
  }

  Future<Document> createMealPlan(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating meal plan: $e");
      rethrow;
    }
  }

  Future<void> deleteMealPlan(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.mealPlansCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting meal plan: $e");
      rethrow;
    }
  }

  // =========================================================================
  // LIFE GOALS DB METHODS
  // =========================================================================

  Future<List<Document>> getLifeGoals() async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");

      final result = await databases.listDocuments(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        queries: [
          Query.equal('userId', user.$id), // FIXED to userId
          Query.orderDesc('\$createdAt'),
        ],
      );
      return result.documents;
    } catch (e) {
      debugPrint("Error fetching life goals: $e");
      return [];
    }
  }

  Future<Document> createLifeGoal(Map<String, dynamic> data) async {
    try {
      final user = await getCurrentUser();
      if (user == null) throw Exception("User not authenticated");
      data['userId'] = user.$id; // FIXED to userId

      return await databases.createDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: ID.unique(),
        data: data,
      );
    } catch (e) {
      debugPrint("Error creating life goal: $e");
      rethrow;
    }
  }

  Future<void> updateLifeGoalProgress(String documentId, int progress) async {
    try {
      await databases.updateDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
        data: {'progress': progress},
      );
    } catch (e) {
      debugPrint("Error updating life goal progress: $e");
      rethrow;
    }
  }

  Future<void> deleteLifeGoal(String documentId) async {
    try {
      await databases.deleteDocument(
        databaseId: Env.appwriteDatabaseId,
        collectionId: Env.lifeGoalsCollection,
        documentId: documentId,
      );
    } catch (e) {
      debugPrint("Error deleting life goal: $e");
      rethrow;
    }
  }
}