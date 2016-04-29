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

@property (nonatomic, copy) SCPProducts productsReturnedSuccessfullyBlock;
@property (nonatomic, copy) SCPProducts invalidProductsBlock;
@property (nonatomic, copy) SCPFailure failureBlock;

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
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
	}

	return self;
}

#pragma mark - SKProductsRequest

- (void)requestProductsWithIdentifiers:(NSSet *)productIdentifiers
					productsReturnedSuccessfully:(SCPProducts)successfulProducts
											 invalidProducts:(SCPProducts)invalidProducts
															 failure:(SCPFailure)failure;
{
	self.productsReturnedSuccessfullyBlock = successfulProducts;
	self.invalidProductsBlock = invalidProducts;
	self.failureBlock = failure;

	SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:productIdentifiers];

	[productsRequest setDelegate:self];
	[productsRequest start];
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
	self.products = response.products;
	if(self.productsReturnedSuccessfullyBlock)
	{
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

- (void)requestPaymentForProduct:(SKProduct *)product
{
	SKPayment *payment = [SKPayment paymentWithProduct:product];

	if([SKPaymentQueue canMakePayments]) {
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		[[SKPaymentQueue defaultQueue] addPayment:payment];
	}
	else {
		NSError *error = [NSError errorWithDomain:SCPStoreKitDomain
																				 code:SCPErrorCodePaymentQueueCanNotMakePayments
														 errorDescription:@"SKPaymentQueue can not make payments"
													 errorFailureReason:@"Has the SKPaymentQueue got any uncompleted purchases?"
											errorRecoverySuggestion:@"Finish all transactions"];
		[self.delegate requestPaymentForProduct:product
										 didCompleteTransaction:nil
																		success:NO
																			error:error];
	}
}

#pragma mark - Restore Purchase

- (void)restoreTransactions;
{
	if([SKPaymentQueue canMakePayments]) {
		[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
		[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
	}
	else {
		NSError *error = [NSError errorWithDomain:SCPStoreKitDomain
																				 code:SCPErrorCodePaymentQueueCanNotMakePayments
														 errorDescription:@"SKPaymentQueue can not make payments"
													 errorFailureReason:@"Has the SKPaymentQueue got any uncompleted purchases?"
											errorRecoverySuggestion:@"Finish all transactions"];
	}
}


#pragma mark - SKPaymentTransactionObserver methods

#pragma mark Updates

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	[self processQueue:queue transactions:transactions];
}

#pragma mark Restoring

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	[self.delegate restoreTransactionsDidComplete:YES error:nil];
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	[self.delegate restoreTransactionsDidComplete:NO error:error];
}

#pragma mark - Miscellaneous

-(SKProduct *)productForTransaction:(SKPaymentTransaction *)transaction {
	for(SKProduct *product in self.products) {
		if( [product.productIdentifier isEqualToString:transaction.payment.productIdentifier]) {
			return product;
		}
	}
	return nil;
}

#pragma mark - Queue helper

-(void)processQueue:(SKPaymentQueue *)queue transactions:(NSArray *)transactions
{
	if([transactions count] > 0)
	{
		[transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction *transaction, NSUInteger idx, BOOL *stop) {

			SKProduct *product = [self productForTransaction:transaction];
			switch([transaction transactionState])
			{
				case SKPaymentTransactionStatePurchased: {
					[queue finishTransaction:transaction];
					[self.delegate requestPaymentForProduct:product
													 didCompleteTransaction:transaction
																					success:YES
																						error:nil];
					break;
				}
				case SKPaymentTransactionStateFailed: {
					[queue finishTransaction:transaction];
					[self.delegate requestPaymentForProduct:product
													 didCompleteTransaction:transaction
																					success:NO
																						error:transaction.error];
					break;
				}
				case SKPaymentTransactionStateRestored: {
					[queue finishTransaction:transaction];
					[self.delegate restoreTransactionsDidRestoreTransaction:transaction];
					break;
				}
				default: {
					break;
				}
			}
		}];
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
