# Firma dell'APK

`fmlab-pubblica.jks` è la firma con cui GitHub firma FMLAB Controller. È fissa, così ogni nuova versione si installa
sopra la precedente senza disinstallare. È pubblica (il repository è pubblico): va bene per un'app installata a mano,
ma non dimostra chi l'ha fatta. Per una firma solo tua: crea un keystore e mettilo nei *Secrets* del repository
(`ANDROID_KEYSTORE` in base64 e `ANDROID_KEYSTORE_PASSWORD`, alias `fmlab`). Il workflow `android` li usa se ci sono.
Cambiando firma, la prima volta Android chiede di disinstallare la versione vecchia.
