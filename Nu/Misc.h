//
//  Misc.h
//  Nu
//
//  Created by arthur on 3/10/12.
//
//

#ifndef Nu_Misc_h
#define Nu_Misc_h

#ifdef __cplusplus
extern "C" {
#endif
    CGRect center_rect_in_size(CGRect sm, CGSize lg);
    CGSize proportional_size(int w, int h, int origw, int origh);
#ifdef __cplusplus
}
#endif

NSString *get_docs_path();
NSString *path_in_docs(NSString *name);
NSString *url_encode(NSString *str);
NSString *path_encode(NSString *str);
void show_alert(NSString *title, NSString *message, NSString *cancel);

#endif
