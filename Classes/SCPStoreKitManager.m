//
//  SCPStoreKitManager.m
//  SCPStoreKitManager
//
//  Created by Ste Prescott on 22/11/2013.
//  Copyright (c) 2013 Ste Prescott. All rights reserved.
//

#import "SCPStoreKitManager.h"

@interface SCPStoreKitManager()

@property (nonatomic, strong) NSNumberFormatter *numberFormatter;

@property (nonatomic, copy) ProductsReturnedSuccessfully productsReturnedSuccessfullyBlock;
@property (nonatomic, copy) InvalidProducts invalidProductsBlock;
@property (nonatomic, copy) Failure failureBlock;

@property (nonatomic, copy) PaymentTransactionStatePurchasing paymentTransactionStatePurchasingBlock;
@property (nonatomic, copy) PaymentTransactionStatePurchased paymentTransactionStatePurchasedBlock;
@property (nonatomic, copy) PaymentTransactionStateFailed paymentTransactionStateFailedBlock;
@property (nonatomic, copy) PaymentTransactionStateRestored paymentTransactionStateRestoredBlock;

@property (nonatomic, copy) SCPSuccess restoreTransactionsSuccess;

@property (nonatomic, strong, readwrite) NSArray *products;

@end

@implementation SCPStoreKitManager

+ (id)sharedInstance
{
	static SCPStoreKitManager *sharedInstance = nil;

	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		sharedInstance = [[self alloc] init];
	});

	return sharedInstance;
}

- (id)init
{
	self = [super init];

	if(self)
	{
		self.numberFormatter = [[NSNumberFormatter alloc] init];
		[self.numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
	}

	return self;
}

#pragma mark - Cleanup

-(void)cleanup
{
	self.invalidProductsBlock = nil;
	self.productsReturnedSuccessfullyBlock = nil;
	self.productsReturnedSuccessfullyBlock = nil;
	self.paymentTransactionStatePurchasingBlock = nil;
	self.paymentTransactionStatePurchasedBlock = nil;
	self.paymentTransactionStateFailedBlock = nil;
	self.paymentTransactionStateRestoredBlock = nil;
	self.failureBlock = nil;
}

#pragma mark - SKProductsRequest

- (void)requestProductsWithIdentifiers:(NSSet *)productsSet
					productsReturnedSuccessfully:(ProductsReturnedSuccessfully)productsReturnedSuccessfullyBlock
											 invalidProducts:(InvalidProducts)invalidProductsBlock
															 failure:(Failure)failureBlock
{
	self.productsReturnedSuccessfullyBlock = productsReturnedSuccessfullyBlock;
	self.invalidProductsBlock = invalidProductsBlock;
	self.failureBlock = failureBlock;

	SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productsSet];

	[productsRequest setDelegate:self];

	[productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	if(self.productsReturnedSuccessfullyBlock)
	{
		self.products = response.products;
		self.productsReturnedSuccessfullyBlock(response.products);
	}

	if([[response invalidProductIdentifiers] count] > 0 && self.invalidProductsBlock)
	{
		self.invalidProductsBlock([response invalidProductIdentifiers]);
	}
	[self cleanupProductsRequest];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
	if(self.failureBlock)
	{
		self.failureBlock(error);
	}
	[self cleanupProductsRequest];
}

-(void)cleanupProductsRequest {
	self.failureBlock = nil;
	self.invalidProductsBlock = nil;
	self.productsReturnedSuccessfullyBlock = nil;
}

#pragma mark - SKPayment

-(void)cleanupPaymentRequest {
	self.paymentTransactionStatePurchasingBlock = nil;
	self.paymentTransactionStatePurchasedBlock = nil;
	self.paymentTransactionStateFailedBlock = nil;
	self.paymentTransactionStateRestoredBlock = nil;
	self.failureBlock = nil;
}
- (void)requestPaymentForProduct:(SKProduct *)product paymentTransactionStatePurchasing:(PaymentTransactionStatePurchasing)paymentTransactionStatePurchasingBlock paymentTransactionStatePurchased:(PaymentTransactionStatePurchased)paymentTransactionStatePurchasedBlock paymentTransactionStateFailed:(PaymentTransactionStateFailed)paymentTransactionStateFailedBlock paymentTransactionStateRestored:(PaymentTransactionStateRestored)paymentTransactionStateRestoredBlock
												 failure:(Failure)failureBlock
{
	self.paymentTransactionStatePurchasingBlock = paymentTransactionStatePurchasingBlock;
	self.paymentTransactionStatePurchasedBlock = paymentTransactionStatePurchasedBlock;
	self.paymentTransactionStateFailedBlock = paymentTransactionStateFailedBlock;
	self.paymentTransactionStateRestoredBlock = paymentTransactionStateRestoredBlock;
	self.failureBlock = failureBlock;

	SKPayment *payment = [SKPayment paymentWithProduct:product];

	if([SKPaymentQueue canMakePayments])
	{
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	else
	{
		if(failureBlock)
		{
			failureBlock([NSError errorWithDomain:SCPStoreKitDomain code:SCPErrorCodePaymentQueueCanNotMakePayments errorDescription:@"SKPaymentQueue can not make payments" errorFailureReason:@"Has the SKPaymentQueue got any uncompleted purchases?" errorRecoverySuggestion:@"Finish all transactions"]);
		}
		[self cleanupPaymentRequest];
	}
}

#pragma mark - Restore Purchase

-(void)cleanupRestorePurchases {
	self.paymentTransactionStateFailedBlock = nil;
	self.paymentTransactionStateRestoredBlock = nil;
	self.restoreTransactionsSuccess = nil;
	self.failureBlock = nil;

}
- (void)restorePurchasesPaymentTransactionStateRestored:(PaymentTransactionStateRestored)paymentTransactionStateRestoredBlock
													paymentTransactionStateFailed:(PaymentTransactionStateFailed)paymentTransactionStateFailedBlock
																								success:(SCPSuccess)success
																								failure:(Failure)failureBlock
{
	self.paymentTransactionStateFailedBlock = paymentTransactionStateFailedBlock;
	self.paymentTransactionStateRestoredBlock = paymentTransactionStateRestoredBlock;
	self.restoreTransactionsSuccess = success;
	self.failureBlock = failureBlock;

	if([SKPaymentQueue canMakePayments])
	{
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
	}
	else
	{
		if(failureBlock)
		{
			failureBlock([NSError errorWithDomain:SCPStoreKitDomain code:SCPErrorCodePaymentQueueCanNotMakePayments errorDescription:@"SKPaymentQueue can not make payments" errorFailureReason:@"Has the SKPaymentQueue got any uncompleted purchases?" errorRecoverySuggestion:@"Finish all transactions"]);
		}
		[self cleanupRestorePurchases];
	}
}


#pragma mark - SKPaymentTransactionObserver methods

#pragma mark Updates

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	NSLog(@"paymentQueueUpdateTransactions");
	[self validateQueue:queue withTransactions:transactions];
}

#pragma mark Restoring

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	NSLog(@"paymentQueueRestoreCompletedTransactionsFinished");
	if( self.restoreTransactionsSuccess ) {
		self.restoreTransactionsSuccess();
	}
	[self cleanupRestorePurchases];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	NSLog(@"restoreCompletedTransactionsFailedWithError: %@", error);
	if(self.failureBlock)
	{
		self.failureBlock(error);
	}
	[self cleanupRestorePurchases];
}


#pragma mark - Queue helper

- (void) validateQueue:(SKPaymentQueue *)queue withTransactions:(NSArray *)transactions
{
	NSLog(@"validateQueue with transactions: %@", transactions);
	if([transactions count] > 0)
	{
		[transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction *transaction, NSUInteger idx, BOOL *stop) {
			NSLog(@"transaction: %@, %d, %@", transaction.payment.productIdentifier, transaction.transactionState, transaction.originalTransaction);

			switch([transaction transactionState])
			{
				case SKPaymentTransactionStatePurchased:
				case SKPaymentTransactionStateFailed:
				case SKPaymentTransactionStateRestored:
				{
					[queue finishTransaction:transaction];
					break;
				}
				default:
				{
					break;
				}
			}

		}];
	}

	if(self.paymentTransactionStatePurchasingBlock)
	{
		NSArray *purchasingTransactions = [transactions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"transactionState == %i", SKPaymentTransactionStatePurchasing]];

		if([purchasingTransactions count] > 0)
		{
			self.paymentTransactionStatePurchasingBlock(purchasingTransactions);
		}
	}

	if(self.paymentTransactionStatePurchasedBlock)
	{
		NSArray *purchasedTransactions = [transactions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"transactionState == %i", SKPaymentTransactionStatePurchased]];

		if([purchasedTransactions count] > 0)
		{
			self.paymentTransactionStatePurchasedBlock(purchasedTransactions);
		}
	}

	if(self.paymentTransactionStateFailedBlock)
	{
		NSArray *failedTransactions = [transactions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"transactionState == %i", SKPaymentTransactionStateFailed]];

		if([failedTransactions count] > 0)
		{
			self.paymentTransactionStateFailedBlock(failedTransactions);
		}
	}

	if(self.paymentTransactionStateRestoredBlock)
	{
		NSArray *restoredTransactions = [transactions filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"transactionState == %i", SKPaymentTransactionStateRestored]];

		self.paymentTransactionStateRestoredBlock(restoredTransactions);
	}
}

#pragma mark - formatter

- (NSString *)localizedPriceForProduct:(SKProduct *)product
{
	[self.numberFormatter setLocale:product.priceLocale];
	NSString *formattedPrice = [self.numberFormatter stringFromNumber:product.price];
	
	return formattedPrice;
}

@end
