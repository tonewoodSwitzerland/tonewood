class Customer {
  final String id;
  final String name;
  final String company;
  final String firstName;
  final String lastName;
  final String street;
  final String houseNumber;
  final String zipCode;
  final String city;
  final String country;
  final String email;

  Customer({
    required this.id,
    required this.name,
    required this.company,
    required this.firstName,
    required this.lastName,
    required this.street,
    required this.houseNumber,
    required this.zipCode,
    required this.city,
    required this.country,
    required this.email,
  });

  factory Customer.fromMap(Map<String, dynamic> map, String id) {
    return Customer(
      id: id,
      name: map['name'] ?? '',
      company: map['company'] ?? '',
      firstName: map['firstName'] ?? '',
      lastName: map['lastName'] ?? '',
      street: map['street'] ?? '',
      houseNumber: map['houseNumber'] ?? '',
      zipCode: map['zipCode'] ?? '',
      city: map['city'] ?? '',
      country: map['country'] ?? '',
      email: map['email'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'company': company,
      'firstName': firstName,
      'lastName': lastName,
      'street': street,
      'houseNumber': houseNumber,
      'zipCode': zipCode,
      'city': city,
      'country': country,
      'email': email,
    };
  }
  String get fullName => '$firstName $lastName';
  String get fullAddress => '$street $houseNumber, $zipCode $city, $country';
}