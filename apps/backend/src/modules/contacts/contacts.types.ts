import { ContentBlock } from '../../common/content/content-blocks';

export interface ContactPersonDto {
  name: string;
  role: string | null;
  description: string | null;
  email: string | null;
  phone: string | null;
  website: string | null;
  profileImage: string | null;
  sortOrder: number;
}

export interface ContactAreaListItemDto {
  slug: string;
  name: string;
  shortDescription: string;
  iconKey: string;
  sortOrder: number;
  generalEmail: string | null;
  phone: string | null;
  website: string | null;
  appointmentUrl: string | null;
  address: string | null;
  openingHours: string | null;
  /** Zero is a valid, fully supported state. */
  personCount: number;
  /** Marks seed data that has not been cleared for publication yet. */
  isDemoContent: boolean;
}

export interface ContactAreaDetailDto extends Omit<ContactAreaListItemDto, 'personCount'> {
  description: ContentBlock[];
  persons: ContactPersonDto[];
}
