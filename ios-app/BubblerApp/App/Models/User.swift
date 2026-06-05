import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let password_hash: String
    let created_at: Date

    enum CodingKeys: String, CodingKey {
        case id  
        case username
        case email 
        case password_hash
        case created_at
    }
}

/*
from dataclasses import dataclass
import datetime

@dataclass
class User:
    id: int
    username: str
    email: str
    password_hash: str
    created_at: datetime.datetime
*/