import '../models/item_model.dart';

/// TEMP client demo: cars-only feed with Unsplash imagery.
/// Set [enabled] to `false` to restore the real catalog.
class DemoCarsFeed {
  static const bool enabled = false;

  static const List<String> categories = [
    'سيارات فاخرة',
    'SUV',
    'رياضية',
    'كهربائية',
  ];

  static final List<_DemoCar> _cars = [
    _DemoCar(
      nameAr: 'مرسيدس S-Class',
      nameEn: 'Mercedes S-Class',
      price: '485000',
      category: 'سيارات فاخرة',
      descriptionAr:
          'سيدان فاخرة بتصميم أنيق وتجهيزات راقية — مقترحة حسب اهتمامك بالسيارات الفاخرة.',
      descriptionEn:
          'Elegant luxury sedan with premium finishes — matched to your luxury car interest.',
      imageUrl:
          'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'بورش 911',
      nameEn: 'Porsche 911',
      price: '620000',
      category: 'رياضية',
      descriptionAr:
          'أيقونة رياضية بأداء استثنائي — ضمن توصيات خوارزمية اهتماماتك.',
      descriptionEn:
          'Iconic sports performance — surfaced by your interest algorithm.',
      imageUrl:
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'رينج روفر فوغ',
      nameEn: 'Range Rover Vogue',
      price: '540000',
      category: 'SUV',
      descriptionAr:
          'SUV فاخرة للمدينة والطرق الطويلة — مناسبة لتفضيلاتك الحالية.',
      descriptionEn:
          'Premium SUV for city and long trips — aligned with your preferences.',
      imageUrl:
          'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'تسلا موديل S',
      nameEn: 'Tesla Model S',
      price: '310000',
      category: 'كهربائية',
      descriptionAr:
          'أداء كهربائي صامت وتقنيات ذكية — مختار لك ضمن فئة السيارات الكهربائية.',
      descriptionEn:
          'Quiet electric performance with smart tech — picked for your EV interest.',
      imageUrl:
          'https://images.unsplash.com/photo-1560958089-b8a1929cea89?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'بي إم دبليو M4',
      nameEn: 'BMW M4',
      price: '455000',
      category: 'رياضية',
      descriptionAr:
          'كوبيه رياضية بطابع عدواني — موصى بها بناءً على سلوك التصفح لديك.',
      descriptionEn:
          'Aggressive sport coupe — recommended from your browsing signals.',
      imageUrl:
          'https://images.unsplash.com/photo-1555215695-3004980ad094?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'أودي RS7',
      nameEn: 'Audi RS7',
      price: '510000',
      category: 'رياضية',
      descriptionAr: 'أداء فائق مع فخامة يومية — ضمن نتائج تخصيص الاحتياجات.',
      descriptionEn:
          'Supercar pace with daily luxury — part of your needs personalization.',
      imageUrl:
          'https://images.unsplash.com/photo-1606664515524-ed2f786a0bd6?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'لامبورغيني هوراكان',
      nameEn: 'Lamborghini Huracán',
      price: '980000',
      category: 'رياضية',
      descriptionAr:
          'سوبركار إيطالية حضورها لا يُنسى — أعلى تطابق مع ذوقك الرياضي.',
      descriptionEn:
          'Unforgettable Italian supercar — top match for your sport taste.',
      imageUrl:
          'https://images.unsplash.com/photo-1544636331-e26879cd4d9b?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'كافالير تاهو',
      nameEn: 'Chevrolet Tahoe',
      price: '275000',
      category: 'SUV',
      descriptionAr:
          'مساحة عائلية كبيرة وقوة سحب ممتازة — مقترحة لاحتياجك العائلي.',
      descriptionEn:
          'Family space and strong capability — suggested for your family need.',
      imageUrl:
          'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'لكزس LX',
      nameEn: 'Lexus LX',
      price: '590000',
      category: 'SUV',
      descriptionAr:
          'فخامة يابانية وموثوقية عالية — ضمن توصيات السيارات الفاخرة لك.',
      descriptionEn:
          'Japanese luxury and reliability — in your luxury recommendations.',
      imageUrl:
          'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'فيراري Roma',
      nameEn: 'Ferrari Roma',
      price: '1250000',
      category: 'رياضية',
      descriptionAr:
          'أناقة إيطالية بروح سباق — اختيار مميز من خوارزمية الذوق الخاص بك.',
      descriptionEn:
          'Italian elegance with racing spirit — a standout from your taste model.',
      imageUrl:
          'https://images.unsplash.com/photo-1583121274602-3e2820c69888?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'مرسيدس G-Class',
      nameEn: 'Mercedes G-Class',
      price: '720000',
      category: 'SUV',
      descriptionAr:
          'أيقونة طرق وعرة بلمسة فاخرة — متوافقة مع تفضيلات الـ SUV لديك.',
      descriptionEn:
          'Iconic off-road luxury — matched to your SUV preferences.',
      imageUrl:
          'https://images.unsplash.com/photo-1606016159991-dfe4f2746ad5?auto=format&fit=crop&w=1080&q=80',
    ),
    _DemoCar(
      nameAr: 'بولستار 2',
      nameEn: 'Polestar 2',
      price: '245000',
      category: 'كهربائية',
      descriptionAr:
          'تصميم اسكندنافي وأداء كهربائي — مقترح لمسار السيارات المستدامة.',
      descriptionEn:
          'Scandinavian design and EV performance — for your sustainable path.',
      imageUrl:
          'https://images.unsplash.com/photo-1617788138017-80ad40651399?auto=format&fit=crop&w=1080&q=80',
    ),
  ];

  static List<ItemModel> items({String? category}) {
    final filtered = (category == null || category.isEmpty)
        ? _cars
        : _cars.where((c) => c.category == category).toList();

    return List.generate(filtered.length, (i) {
      final car = filtered[i];
      return ItemModel(
        id: 'demo_car_${car.category}_$i',
        idx: 'demo_car_$i',
        storeid: '1',
        name: car.nameAr,
        nameEn: car.nameEn,
        price: car.price,
        quantity: 1,
        description: car.descriptionEn,
        descriptionArb: car.descriptionAr,
        views: 1200 + (i * 137),
        media: [car.imageUrl],
        seller: SellerModel(
          id: 'demo_seller',
          uid: 'demo_seller',
          name: 'MartIt Motors',
          avatar: '',
        ),
        interactions: InteractionsModel(
          likes: 40 + i * 3,
          comments: 5 + i,
          shares: 2 + (i % 4),
          cartQuantity: 0,
          isLiked: false,
        ),
      );
    });
  }
}

class _DemoCar {
  final String nameAr;
  final String nameEn;
  final String price;
  final String category;
  final String descriptionAr;
  final String descriptionEn;
  final String imageUrl;

  const _DemoCar({
    required this.nameAr,
    required this.nameEn,
    required this.price,
    required this.category,
    required this.descriptionAr,
    required this.descriptionEn,
    required this.imageUrl,
  });
}
