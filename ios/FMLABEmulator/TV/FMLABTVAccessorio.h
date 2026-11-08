// FMLAB Emulator: lo schermo esterno di iOS 27 (vedi FMLABTVAccessorio.m).
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Su iOS 27 la TV (Duplica schermo o cavo) diventa uno schermo SEPARATO dell'app solo se l'app registra un
/// "accessorio" sul controller della finestra principale. Senza, iOS duplica e basta (la TV mostra il telefono).
/// Su iOS 15–26 basta la scena dichiarata in Info.plist e questa funzione non fa niente.
/// Ritorna lo stato: "registrato", "API non trovata", "registrazione non riuscita" o "non serve".
FOUNDATION_EXPORT NSString *FMLABRegistraSchermoEsterno(UIViewController *controller, Class delegato);

/// Accende o spegne la richiesta (Impostazioni › TV). Spenta, iOS 27 torna a duplicare lo schermo.
FOUNDATION_EXPORT void FMLABAbilitaSchermoEsterno(UIViewController *controller, BOOL acceso);

NS_ASSUME_NONNULL_END
