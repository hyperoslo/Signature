//
//  ViewController.m
//  GRKSignatureViewTestApp
//
//  Created by Levi Brown on 9/29/17.
//  Copyright © 2017 Levi Brown. All rights reserved.
//

#import "ViewController.h"
#import <GRKSignatureView/GRKSignatureView.h>

@interface ViewController ()

@property (nonatomic, weak) IBOutlet GRKSignatureView *signatureView;
@property (nonatomic, weak) IBOutlet UISwitch *longPressSwitch;

- (IBAction)clearAction:(id)sender;
- (IBAction)longPressValueChanged:(id)sender;

@end

@implementation ViewController

#pragma mark - Lifecycle

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	self.longPressSwitch.on = self.signatureView.eraseOnLongPress;
}

#pragma mark - Actions

- (IBAction)clearAction:(id)sender
{
	NSLog(@"clearAction:");
	[self.signatureView erase];
}

- (IBAction)longPressValueChanged:(UISwitch *)sender
{
	NSLog(@"longPressValueChanged:");
	self.signatureView.eraseOnLongPress = sender.on;
}

@end
