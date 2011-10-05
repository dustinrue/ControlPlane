//
//  DB.h
//  ControlPlane
//
//  Created by David Symonds on 29/03/07.
//

@interface DB : NSObject {
	NSDictionary *m_ouiDB;
	NSDictionary *m_usbVendorDB;
}

+ (DB *) sharedDB;
@property (readonly) NSDictionary *ouiDB;
@property (readonly) NSDictionary *usbVendorDB;

@end
