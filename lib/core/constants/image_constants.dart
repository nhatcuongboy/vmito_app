/// Image URLs and constants used throughout the app.
///
/// This file contains default images, placeholders, and Cloudinary configurations.
library;

/// Default cover photo for sessions, venues, clubs, and tournaments.
///
/// Uses Cloudinary with auto format, auto quality, max width 800px.
/// Cloudinary will serve AVIF/WebP at the appropriate display size.
const String kDefaultCoverPhoto =
    'https://res.cloudinary.com/dzehhkd9m/image/upload/f_auto,q_auto,w_800,c_limit/v1778918839/badminton/session-covers/vtwinrsl4ffness0os42.jpg';

/// Default club logo path (local asset).
const String kDefaultClubLogo = '/icons/app-logo-96.png';
