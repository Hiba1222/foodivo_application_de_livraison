import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Same model as the website: English text is the key, French comes from
/// assets/i18n/fr.json (exported from web/lib/i18n/fr.ts) + the mobile-only texts below.
const _mobileFr = <String, String>{
  'No internet connection': 'Pas de connexion internet',
  'Retry': 'Réessayer',
  'Account': 'Compte',
  'Change': 'Modifier',
  'Order placed!': 'Commande envoyée !',
  'Add to cart': 'Ajouter au panier',
  'Cancel': 'Annuler',
  'Clear and continue': 'Vider et continuer',
  'New order?': 'Nouvelle commande ?',
  'Track order': 'Suivre la commande',
  'Phone number is required': 'Le numéro de téléphone est obligatoire',
  'Required field': 'Champ obligatoire',
  'Password must be at least 6 characters': 'Le mot de passe doit contenir au moins 6 caractères',
  'Pull down to refresh': 'Tirez pour actualiser',
  'Signed in as {name}': 'Connecté en tant que {name}',
  // Restaurant & driver apps
  'Admin accounts: please use the Foodivo website.': 'Comptes administrateur : veuillez utiliser le site Foodivo.',
  'Call the restaurant': 'Appeler le restaurant',
  'Choose from gallery': 'Choisir dans la galerie',
  'Take a photo': 'Prendre une photo',
  'Customer can remove each ingredient or ask for extra.': 'Le client peut retirer chaque ingrédient ou en demander plus.',
  'Customer picks from a list (bread, size, sauces, paid extras).': 'Le client choisit dans une liste (pain, taille, sauces, suppléments payants).',
  'Delete this item from your menu?': 'Supprimer ce plat de votre menu ?',
  'Delivery accepted! Find it in My deliveries.': 'Livraison acceptée ! Retrouvez-la dans Mes livraisons.',
  'Discount & special offer': 'Réduction et offre spéciale',
  'Ends': 'Se termine',
  'Group name': 'Nom du groupe',
  'Leave empty for no discount. Must be lower than {price}.': 'Laissez vide pour aucune réduction. Doit être inférieur à {price}.',
  'No end date': 'Pas de date de fin',
  'Set end date': 'Définir une date de fin',
  'Offer price (TND)': 'Prix promo (TND)',
  'Show this item in the Special offers section at the top of your menu.': 'Afficher ce plat dans la section Offres spéciales en haut de votre menu.',
  'Tap an item to edit its photo, price, offer and options. Use the switch to hide it instantly.':
      'Touchez un plat pour modifier sa photo, son prix, son offre et ses options. Utilisez l’interrupteur pour le masquer instantanément.',
  'Your location is shared with customers while you are online.': 'Votre position est partagée avec les clients tant que vous êtes en ligne.',
  'e.g. Choose your drink': 'ex. Choisissez votre boisson',
  'e.g. Ramadan special': 'ex. Spécial Ramadan',
  // Interactive staff screens + admin app
  'Good morning': 'Bonjour',
  'Good afternoon': 'Bon après-midi',
  'Good evening': 'Bonsoir',
  'Active': 'En cours',
  'Completed': 'Terminées',
  'Ready': 'Prête',
  'On the way': 'En route',
  'Search': 'Rechercher',
  'New order!': 'Nouvelle commande !',
  'New delivery available!': 'Nouvelle livraison disponible !',
  'Reject this order?': 'Refuser cette commande ?',
  'No new orders right now.': 'Aucune nouvelle commande pour le moment.',
  'Slide when ready for pickup': 'Glissez quand c’est prêt',
  'Slide when picked up': 'Glissez une fois récupérée',
  'Slide when delivered': 'Glissez une fois livrée',
  'Go online to start receiving delivery requests.': 'Passez en ligne pour recevoir des demandes de livraison.',
  "We'll buzz you as soon as an order is ready.": 'Votre téléphone vibrera dès qu’une commande sera prête.',
  'Waiting for your approval': 'En attente de votre approbation',
  'Nothing waiting for approval.': 'Rien en attente d’approbation.',
};

class I18n extends ChangeNotifier {
  static const _prefKey = 'lang';
  Map<String, String> _fr = {};
  String _locale = 'en';

  String get locale => _locale;
  bool get isFr => _locale == 'fr';
  String get dateTag => isFr ? 'fr_FR' : 'en_GB';

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/i18n/fr.json');
    _fr = {...(jsonDecode(raw) as Map<String, dynamic>).cast<String, String>(), ..._mobileFr};
    await initializeDateFormatting('fr_FR');
    await initializeDateFormatting('en_GB');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'fr' || saved == 'en') {
      _locale = saved!;
    } else {
      // First launch: follow the phone's language.
      final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      _locale = device == 'fr' ? 'fr' : 'en';
    }
  }

  Future<void> setLocale(String value) async {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, value);
  }

  String t(String key, [Map<String, Object?>? vars]) {
    var text = isFr ? (_fr[key] ?? key) : key;
    vars?.forEach((k, v) => text = text.replaceAll('{$k}', '$v'));
    return text;
  }

  String dateTime(String iso) => DateFormat.yMMMd(dateTag).add_Hm().format(DateTime.parse(iso).toLocal());
  String time(String iso) => DateFormat.Hm(dateTag).format(DateTime.parse(iso).toLocal());
  String date(String iso) => DateFormat.yMMMd(dateTag).format(DateTime.parse(iso).toLocal());

  static const statusText = {
    'pending': 'Pending',
    'accepted': 'Accepted',
    'rejected': 'Rejected',
    'ready_for_pickup': 'Ready for pickup',
    'driver_assigned': 'Driver assigned',
    'picked_up': 'Picked up',
    'delivered': 'Delivered',
    'cancelled': 'Cancelled',
  };
  String status(String s) => t(statusText[s] ?? s.replaceAll('_', ' '));
}
