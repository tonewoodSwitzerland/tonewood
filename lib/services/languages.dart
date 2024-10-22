import 'package:get/get.dart';

class LocalString extends Translations{

  @override

  Map<String, Map<String, String>> get keys =>{
    'en_US':{
      'password':                    'password',
      'passwordError':               'please use more than 6 characters',
      'loginFailed':                 'Failed to log in. Please check your credentials and try again.',
      'mail':                        'mail',
      'emptyMail':                   'add mail address',
      'loginButton':                 'login',
      'backLogin':                   'go back',
      'forget':                      'forget password',
      'resetPassword':                'reset password',
      'register':                    'register',
      'camera':                      'camera',
      'gallery':                     'gallery',
      'noData':                      'No data found for this barcode',
      'group':                       'user group',
      'yourAccount':                 'your Account',
      'save':                        'save',
      'scanPackage':                'scan Package',
      'inviteCode':                 'invitation code',
      'emptyMail':                  'add invitation code',
      'invalidInvitee':             'invalid invitation code',
      'emailSent':                   'email has been send, please confirm the mail address',
      'stockLevel':                  'warehouse stock',
      'noChanges':                   'not saved - no changes',
      'changesSaved':                'changes saved',
      'feedbackSent':                'feedback sent'
    },


    'de_DE':{
      'password':                    'Passwort',
      'passwordError':               'Passwort muss mehr als 6 Zeichen haben.',
      'loginFailed':                 'Login fehlgeschlagen. Bitte prüfe deine Zugangsdaten.',
      'mail':                        'E-Mail-Adresse',
      'emptyMail':                   'keine Emailadresse eingegeben',
      'loginButton':                 'Anmelden',
      'backLogin':                   'zurück',
      'forget':                      'Passwort vergessen',
      'resetPassword':                'Passwort zurücksetzen',
      'register':                    'Registrierung',
      'camera':                      'Kamera',
      'gallery':                     'Bilder',
      'noData':                      'kein Paket zuordbar',
      'group':                       'Nutzergruppe: ',
      'yourAccount':                 'Dein Zugang',
      'save':                        'Speichern',
      'scanPackage':                'Paket scannen',
      'inviteCode':                 'Einladungscode',
      'emptyMail':                  'kein Einladungscode eingegeben',
      'invalidInvitee':             'Einladungscode nicht gültig',
      "emailSent":                    'Email wurde versendet, bitte bestätige deine Mailadresse',
      'stockLevel':                  'Warenbestand',
      'noChanges':                   'nicht gespeichert - keine Änderungen',
      'changesSaved':                'Änderungen gespeichert',
      'feedbackSent':                'Feedback abgeschickt'
    }

  };
}