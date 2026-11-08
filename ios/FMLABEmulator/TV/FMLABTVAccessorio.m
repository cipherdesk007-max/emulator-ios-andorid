// FMLAB Emulator: registrazione dello schermo esterno su iOS 27, lo stesso metodo di FMLAB Linux (LinuxRunner,
// GUIViewController.m, registerExternalDisplayForController:), che lì porta il desktop sulla TV.
// L'app si compila con l'SDK di GitHub (più vecchio di iOS 27): l'API si chiama a runtime per nome.
#import "FMLABTVAccessorio.h"
#import <objc/message.h>
#import <objc/runtime.h>

static char FMLABChiaveAccessorio;

NSString *FMLABRegistraSchermoEsterno(UIViewController *controller, Class delegato) {
    if (@available(iOS 27.0, *)) {
        if (objc_getAssociatedObject(controller, &FMLABChiaveAccessorio)) return @"registrato";
        Class accessorio = NSClassFromString(@"UISceneAccessory");
        SEL crea = NSSelectorFromString(@"externalNonInteractiveSceneAccessoryWithConfiguration:");
        SEL registra = NSSelectorFromString(@"registerSceneAccessory:");
        if (!accessorio || ![accessorio respondsToSelector:crea] || ![controller respondsToSelector:registra]) return @"API non trovata";
        UISceneConfiguration *configurazione = [[UISceneConfiguration alloc] initWithName:@"TV" sessionRole:UIWindowSceneSessionRoleExternalDisplayNonInteractive];
        configurazione.delegateClass = delegato;
        id registrazione = nil;
        @try {
            id acc = ((id (*)(id, SEL, id))objc_msgSend)(accessorio, crea, configurazione);
            registrazione = acc ? ((id (*)(id, SEL, id))objc_msgSend)(controller, registra, acc) : nil;
        } @catch (NSException *e) { NSLog(@"FMLAB TV: %@", e); }
        if (!registrazione) return @"registrazione non riuscita";
        objc_setAssociatedObject(controller, &FMLABChiaveAccessorio, registrazione, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        FMLABAbilitaSchermoEsterno(controller, YES);
        return @"registrato";
    }
    return @"non serve";
}

void FMLABAbilitaSchermoEsterno(UIViewController *controller, BOOL acceso) {
    id registrazione = objc_getAssociatedObject(controller, &FMLABChiaveAccessorio);
    SEL abilita = NSSelectorFromString(@"setEnabled:");
    if (registrazione && [registrazione respondsToSelector:abilita]) ((void (*)(id, SEL, BOOL))objc_msgSend)(registrazione, abilita, acceso);
}
