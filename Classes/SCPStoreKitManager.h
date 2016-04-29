//
//  SCPStoreKitManager.h
//  SCPStoreKitManager
//
//  Created by Ste Prescott on 22/11/2013.
//  Copyright (c) 2013 Ste Prescott. All rights reserved.
//

@import Foundation;
@import StoreKit;

#import "NSError+SCPStoreKitManager.h"

typedef void(^SCPSuccess)(void);
typedef void(^SCPFailure)(NSError *error);
typedef void(^SCPProducts)(NSArray *products);
typedef void(^SCPTransactions)(NSArray *transactions);

@protocol SCPStoreKitManagerDelegate

-(void)requestPaymentForProduct:(SKProduct *)product
				 didCompleteTransaction:(SKPaymentTransaction *)transaction
												success:(BOOL)success
													error:(NSError *)error;
-(void)restoreTransactionsDidRestoreTransaction:(SKPaymentTransaction *)transaction;
-(void)restoreTransactionsDidComplete:(BOOL)success error:(NSError *)error;

@end

@interface SCPStoreKitManager : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>

@property (nonatomic, strong, readonly) NSArray *products;
@property (assign, nonatomic) id<SCPStoreKitManagerDelegate> delegate;

+(instancetype)sharedInstance;

- (void)requestProductsWithIdentifiers:(NSSet *)productIdentifiers
					productsReturnedSuccessfully:(SCPProducts)successfulProducts
											 invalidProducts:(SCPProducts)invalidProducts
															 failure:(SCPFailure)failure;

- (void)requestPaymentForProduct:(SKProduct *)product;

- (void)restoreTransactions;

- (NSString *)localizedPriceForProduct:(SKProduct *)product;

@end
