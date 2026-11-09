export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      alert_rules: {
        Row: {
          active: boolean
          channels: string[]
          code: string
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          property_id: string | null
          threshold: Json
          updated_at: string
          urgent: boolean
        }
        Insert: {
          active?: boolean
          channels?: string[]
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id: string
          property_id?: string | null
          threshold?: Json
          updated_at?: string
          urgent?: boolean
        }
        Update: {
          active?: boolean
          channels?: string[]
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id?: string
          property_id?: string | null
          threshold?: Json
          updated_at?: string
          urgent?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "alert_rules_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alert_rules_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      approval_rules: {
        Row: {
          approver_role_id: string | null
          approver_user_id: string | null
          condition: Json
          created_at: string
          created_by: string | null
          doc_type: string
          id: string
          item_group_id: string | null
          max_amount: number | null
          min_amount: number
          org_id: string
          property_id: string | null
          required_perm: string
          step: number
          updated_at: string
        }
        Insert: {
          approver_role_id?: string | null
          approver_user_id?: string | null
          condition?: Json
          created_at?: string
          created_by?: string | null
          doc_type: string
          id?: string
          item_group_id?: string | null
          max_amount?: number | null
          min_amount?: number
          org_id: string
          property_id?: string | null
          required_perm?: string
          step: number
          updated_at?: string
        }
        Update: {
          approver_role_id?: string | null
          approver_user_id?: string | null
          condition?: Json
          created_at?: string
          created_by?: string | null
          doc_type?: string
          id?: string
          item_group_id?: string | null
          max_amount?: number | null
          min_amount?: number
          org_id?: string
          property_id?: string | null
          required_perm?: string
          step?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_rules_approver_role_id_org_id_fkey"
            columns: ["approver_role_id", "org_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "approval_rules_item_group_org_fkey"
            columns: ["item_group_id", "org_id"]
            isOneToOne: false
            referencedRelation: "item_groups"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "approval_rules_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approval_rules_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "approval_rules_required_perm_fkey"
            columns: ["required_perm"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["code"]
          },
        ]
      }
      audit_log: {
        Row: {
          action: string
          actor: string | null
          at: string
          client_info: Json
          id: number
          new_data: Json | null
          old_data: Json | null
          row_id: string
          table_name: string
        }
        Insert: {
          action: string
          actor?: string | null
          at?: string
          client_info?: Json
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          row_id: string
          table_name: string
        }
        Update: {
          action?: string
          actor?: string | null
          at?: string
          client_info?: Json
          id?: never
          new_data?: Json | null
          old_data?: Json | null
          row_id?: string
          table_name?: string
        }
        Relationships: []
      }
      ceiling_prices: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          org_id: string
          price: number
          property_id: string | null
          set_by: string
          uom: string
          updated_at: string
          valid_from: string
          valid_to: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          org_id: string
          price: number
          property_id?: string | null
          set_by: string
          uom: string
          updated_at?: string
          valid_from: string
          valid_to: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          org_id?: string
          price?: number
          property_id?: string | null
          set_by?: string
          uom?: string
          updated_at?: string
          valid_from?: string
          valid_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "ceiling_prices_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "ceiling_prices_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ceiling_prices_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "ceiling_prices_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      cost_centers: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          updated_at: string
          usali_department: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          updated_at?: string
          usali_department?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          updated_at?: string
          usali_department?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cost_centers_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      doc_sequences: {
        Row: {
          doc_type: string
          last_no: number
          legal_entity_id: string
          year: number
        }
        Insert: {
          doc_type: string
          last_no: number
          legal_entity_id: string
          year: number
        }
        Update: {
          doc_type?: string
          last_no?: number
          legal_entity_id?: string
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "doc_sequences_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
        ]
      }
      expense_categories: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          external_codes: Json
          id: string
          name: string
          org_id: string
          parent_id: string | null
          updated_at: string
          usali_line: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          id?: string
          name: string
          org_id: string
          parent_id?: string | null
          updated_at?: string
          usali_line?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          id?: string
          name?: string
          org_id?: string
          parent_id?: string | null
          updated_at?: string
          usali_line?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "expense_categories_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "expense_categories_parent_id_org_id_fkey"
            columns: ["parent_id", "org_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      item_groups: {
        Row: {
          code_prefix: string
          created_at: string
          created_by: string | null
          id: string
          kind: string
          name: string
          org_id: string
          parent_id: string | null
          updated_at: string
        }
        Insert: {
          code_prefix: string
          created_at?: string
          created_by?: string | null
          id?: string
          kind: string
          name: string
          org_id: string
          parent_id?: string | null
          updated_at?: string
        }
        Update: {
          code_prefix?: string
          created_at?: string
          created_by?: string | null
          id?: string
          kind?: string
          name?: string
          org_id?: string
          parent_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_groups_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_groups_parent_id_org_id_fkey"
            columns: ["parent_id", "org_id"]
            isOneToOne: false
            referencedRelation: "item_groups"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      item_purchase_units: {
        Row: {
          created_at: string
          created_by: string | null
          factor_to_stock: number
          id: string
          is_default: boolean
          item_id: string
          org_id: string
          supplier_id: string | null
          uom: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          factor_to_stock: number
          id?: string
          is_default?: boolean
          item_id: string
          org_id: string
          supplier_id?: string | null
          uom: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          factor_to_stock?: number
          id?: string
          is_default?: boolean
          item_id?: string
          org_id?: string
          supplier_id?: string | null
          uom?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_purchase_units_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "item_purchase_units_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_purchase_units_supplier_id_org_id_fkey"
            columns: ["supplier_id", "org_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "item_purchase_units_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      items: {
        Row: {
          abc_class: string | null
          allowed_channels: string[]
          code: string
          created_at: string
          created_by: string | null
          density_g_ml: number | null
          external_codes: Json
          group_id: string
          id: string
          is_key_item: boolean
          is_temp: boolean
          legacy_code: string | null
          merged_into_id: string | null
          name: string
          name_en: string | null
          name_norm: string | null
          org_id: string
          recipe_uom: string | null
          shelf_life_days: number | null
          status: string
          stock_to_recipe: number | null
          stock_uom: string
          storage_condition: string | null
          tare_g: number | null
          temp_created_at: string | null
          track_lot: boolean
          updated_at: string
          vat_rate: number | null
        }
        Insert: {
          abc_class?: string | null
          allowed_channels?: string[]
          code: string
          created_at?: string
          created_by?: string | null
          density_g_ml?: number | null
          external_codes?: Json
          group_id: string
          id?: string
          is_key_item?: boolean
          is_temp?: boolean
          legacy_code?: string | null
          merged_into_id?: string | null
          name: string
          name_en?: string | null
          name_norm?: string | null
          org_id: string
          recipe_uom?: string | null
          shelf_life_days?: number | null
          status?: string
          stock_to_recipe?: number | null
          stock_uom: string
          storage_condition?: string | null
          tare_g?: number | null
          temp_created_at?: string | null
          track_lot?: boolean
          updated_at?: string
          vat_rate?: number | null
        }
        Update: {
          abc_class?: string | null
          allowed_channels?: string[]
          code?: string
          created_at?: string
          created_by?: string | null
          density_g_ml?: number | null
          external_codes?: Json
          group_id?: string
          id?: string
          is_key_item?: boolean
          is_temp?: boolean
          legacy_code?: string | null
          merged_into_id?: string | null
          name?: string
          name_en?: string | null
          name_norm?: string | null
          org_id?: string
          recipe_uom?: string | null
          shelf_life_days?: number | null
          status?: string
          stock_to_recipe?: number | null
          stock_uom?: string
          storage_condition?: string | null
          tare_g?: number | null
          temp_created_at?: string | null
          track_lot?: boolean
          updated_at?: string
          vat_rate?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "items_group_id_org_id_fkey"
            columns: ["group_id", "org_id"]
            isOneToOne: false
            referencedRelation: "item_groups"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "items_merged_into_id_org_id_fkey"
            columns: ["merged_into_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "items_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "items_recipe_uom_fkey"
            columns: ["recipe_uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "items_stock_uom_fkey"
            columns: ["stock_uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      legal_entities: {
        Row: {
          accounting_regime: string
          code: string
          costing_method: string
          created_at: string
          created_by: string | null
          external_codes: Json
          id: string
          name: string
          org_id: string
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          accounting_regime?: string
          code: string
          costing_method?: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          id?: string
          name: string
          org_id: string
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          accounting_regime?: string
          code?: string
          costing_method?: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          id?: string
          name?: string
          org_id?: string
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "legal_entities_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organizations: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: []
      }
      outlet_types: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          name: string
          org_id: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          org_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          org_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "outlet_types_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      outlets: {
        Row: {
          code: string
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          id: string
          name: string
          outlet_type_id: string
          property_id: string
          updated_at: string
        }
        Insert: {
          code: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name: string
          outlet_type_id: string
          property_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          name?: string
          outlet_type_id?: string
          property_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "outlets_cost_center_id_fkey"
            columns: ["cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outlets_outlet_type_id_fkey"
            columns: ["outlet_type_id"]
            isOneToOne: false
            referencedRelation: "outlet_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "outlets_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      permissions: {
        Row: {
          code: string
          created_at: string
          description_vi: string
          module: string
          name_vi: string
          risk_level: string
          sort_order: number
        }
        Insert: {
          code: string
          created_at?: string
          description_vi: string
          module: string
          name_vi: string
          risk_level: string
          sort_order: number
        }
        Update: {
          code?: string
          created_at?: string
          description_vi?: string
          module?: string
          name_vi?: string
          risk_level?: string
          sort_order?: number
        }
        Relationships: []
      }
      price_agreement_lines: {
        Row: {
          agreement_id: string
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          lock_pct: number | null
          org_id: string
          unit_price: number
          uom: string
          updated_at: string
          warn_pct: number | null
        }
        Insert: {
          agreement_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          lock_pct?: number | null
          org_id: string
          unit_price: number
          uom: string
          updated_at?: string
          warn_pct?: number | null
        }
        Update: {
          agreement_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          lock_pct?: number | null
          org_id?: string
          unit_price?: number
          uom?: string
          updated_at?: string
          warn_pct?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "price_agreement_lines_agreement_id_org_id_fkey"
            columns: ["agreement_id", "org_id"]
            isOneToOne: false
            referencedRelation: "price_agreements"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "price_agreement_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "price_agreement_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "price_agreement_lines_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      price_agreements: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          status: string
          supplier_id: string
          updated_at: string
          valid_from: string
          valid_to: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          org_id: string
          status?: string
          supplier_id: string
          updated_at?: string
          valid_from: string
          valid_to: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          org_id?: string
          status?: string
          supplier_id?: string
          updated_at?: string
          valid_from?: string
          valid_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "price_agreements_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "price_agreements_supplier_id_org_id_fkey"
            columns: ["supplier_id", "org_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      profiles: {
        Row: {
          active: boolean
          created_at: string
          employee_code: string | null
          full_name: string
          id: string
          phone: string | null
          pin_hash: string | null
          updated_at: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          employee_code?: string | null
          full_name?: string
          id: string
          phone?: string | null
          pin_hash?: string | null
          updated_at?: string
        }
        Update: {
          active?: boolean
          created_at?: string
          employee_code?: string | null
          full_name?: string
          id?: string
          phone?: string | null
          pin_hash?: string | null
          updated_at?: string
        }
        Relationships: []
      }
      properties: {
        Row: {
          address: string | null
          code: string
          created_at: string
          created_by: string | null
          id: string
          legal_entity_id: string
          name: string
          org_id: string
          rooms_count: number
          sod_profile: string
          updated_at: string
        }
        Insert: {
          address?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id: string
          name: string
          org_id: string
          rooms_count?: number
          sod_profile?: string
          updated_at?: string
        }
        Update: {
          address?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id?: string
          name?: string
          org_id?: string
          rooms_count?: number
          sod_profile?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "properties_legal_entity_id_org_id_fkey"
            columns: ["legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "properties_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          created_by: string | null
          permission_code: string
          role_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          permission_code: string
          role_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          permission_code?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_code_fkey"
            columns: ["permission_code"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          active: boolean
          code: string
          copied_from_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          id: string
          is_system: boolean
          name_vi: string
          org_id: string
          updated_at: string
        }
        Insert: {
          active?: boolean
          code: string
          copied_from_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_system?: boolean
          name_vi: string
          org_id: string
          updated_at?: string
        }
        Update: {
          active?: boolean
          code?: string
          copied_from_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          id?: string
          is_system?: boolean
          name_vi?: string
          org_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "roles_copied_from_id_fkey"
            columns: ["copied_from_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "roles_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      room_types: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          max_guests: number | null
          name: string
          property_id: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          max_guests?: number | null
          name: string
          property_id: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          max_guests?: number | null
          name?: string
          property_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_types_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      rooms: {
        Row: {
          created_at: string
          created_by: string | null
          floor: string | null
          id: string
          property_id: string
          room_no: string
          room_type_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          floor?: string | null
          id?: string
          property_id: string
          room_no: string
          room_type_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          floor?: string | null
          id?: string
          property_id?: string
          room_no?: string
          room_type_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rooms_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rooms_room_type_id_property_id_fkey"
            columns: ["room_type_id", "property_id"]
            isOneToOne: false
            referencedRelation: "room_types"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      settings: {
        Row: {
          created_at: string
          id: string
          key: string
          org_id: string
          property_id: string | null
          updated_at: string
          updated_by: string | null
          value: Json
        }
        Insert: {
          created_at?: string
          id?: string
          key: string
          org_id: string
          property_id?: string | null
          updated_at?: string
          updated_by?: string | null
          value: Json
        }
        Update: {
          created_at?: string
          id?: string
          key?: string
          org_id?: string
          property_id?: string | null
          updated_at?: string
          updated_by?: string | null
          value?: Json
        }
        Relationships: [
          {
            foreignKeyName: "settings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "settings_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      sod_exceptions: {
        Row: {
          approved_by: string
          created_at: string
          created_by: string | null
          id: string
          property_id: string
          reason: string
          rule_code: string
          updated_at: string
          user_id: string
          valid_to: string
        }
        Insert: {
          approved_by: string
          created_at?: string
          created_by?: string | null
          id?: string
          property_id: string
          reason: string
          rule_code: string
          updated_at?: string
          user_id: string
          valid_to: string
        }
        Update: {
          approved_by?: string
          created_at?: string
          created_by?: string | null
          id?: string
          property_id?: string
          reason?: string
          rule_code?: string
          updated_at?: string
          user_id?: string
          valid_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "sod_exceptions_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_bank_accounts: {
        Row: {
          account_name: string
          account_no: string
          approved_at: string | null
          approved_by: string | null
          bank_name: string
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          requested_by: string
          status: string
          supplier_id: string
          updated_at: string
        }
        Insert: {
          account_name: string
          account_no: string
          approved_at?: string | null
          approved_by?: string | null
          bank_name: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id: string
          requested_by: string
          status?: string
          supplier_id: string
          updated_at?: string
        }
        Update: {
          account_name?: string
          account_no?: string
          approved_at?: string | null
          approved_by?: string | null
          bank_name?: string
          created_at?: string
          created_by?: string | null
          id?: string
          org_id?: string
          requested_by?: string
          status?: string
          supplier_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_bank_accounts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_bank_accounts_supplier_id_org_id_fkey"
            columns: ["supplier_id", "org_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      suppliers: {
        Row: {
          address: string | null
          approved_by: string | null
          code: string
          created_at: string
          created_by: string | null
          external_codes: Json
          food_safety_cert_until: string | null
          id: string
          kind: string
          name: string
          org_id: string
          payment_terms_days: number | null
          phone: string | null
          status: string
          tax_code: string | null
          updated_at: string
        }
        Insert: {
          address?: string | null
          approved_by?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          food_safety_cert_until?: string | null
          id?: string
          kind: string
          name: string
          org_id: string
          payment_terms_days?: number | null
          phone?: string | null
          status?: string
          tax_code?: string | null
          updated_at?: string
        }
        Update: {
          address?: string | null
          approved_by?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          external_codes?: Json
          food_safety_cert_until?: string | null
          id?: string
          kind?: string
          name?: string
          org_id?: string
          payment_terms_days?: number | null
          phone?: string | null
          status?: string
          tax_code?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "suppliers_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      uoms: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          name_vi: string
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          name_vi: string
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          name_vi?: string
          updated_at?: string
        }
        Relationships: []
      }
      user_permission_overrides: {
        Row: {
          created_at: string
          effect: string
          granted_by: string | null
          id: string
          permission_code: string
          property_id: string | null
          reason: string
          updated_at: string
          user_id: string
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          created_at?: string
          effect: string
          granted_by?: string | null
          id?: string
          permission_code: string
          property_id?: string | null
          reason: string
          updated_at?: string
          user_id: string
          valid_from?: string
          valid_to?: string | null
        }
        Update: {
          created_at?: string
          effect?: string
          granted_by?: string | null
          id?: string
          permission_code?: string
          property_id?: string | null
          reason?: string
          updated_at?: string
          user_id?: string
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_permission_overrides_permission_code_fkey"
            columns: ["permission_code"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "user_permission_overrides_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      user_property_roles: {
        Row: {
          created_at: string
          granted_by: string | null
          id: string
          outlet_ids: string[] | null
          property_id: string | null
          role_id: string
          updated_at: string
          user_id: string
          valid_from: string
          valid_to: string | null
          warehouse_ids: string[] | null
        }
        Insert: {
          created_at?: string
          granted_by?: string | null
          id?: string
          outlet_ids?: string[] | null
          property_id?: string | null
          role_id: string
          updated_at?: string
          user_id: string
          valid_from?: string
          valid_to?: string | null
          warehouse_ids?: string[] | null
        }
        Update: {
          created_at?: string
          granted_by?: string | null
          id?: string
          outlet_ids?: string[] | null
          property_id?: string | null
          role_id?: string
          updated_at?: string
          user_id?: string
          valid_from?: string
          valid_to?: string | null
          warehouse_ids?: string[] | null
        }
        Relationships: [
          {
            foreignKeyName: "user_property_roles_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_property_roles_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      warehouses: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          id: string
          kind: string
          name: string
          outlet_id: string | null
          property_id: string
          room_id: string | null
          updated_at: string
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          id?: string
          kind: string
          name: string
          outlet_id?: string | null
          property_id: string
          room_id?: string | null
          updated_at?: string
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          id?: string
          kind?: string
          name?: string
          outlet_id?: string | null
          property_id?: string
          room_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "warehouses_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouses_outlet_id_property_id_fkey"
            columns: ["outlet_id", "property_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "warehouses_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouses_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "warehouses_room_id_property_id_fkey"
            columns: ["room_id", "property_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      _admin_config_require_perm: {
        Args: { p_org_id: string; p_permission: string; p_property_id: string }
        Returns: undefined
      }
      _admin_setting_default: { Args: { p_key: string }; Returns: Json }
      _setting_get: {
        Args: { p_key: string; p_org_id: string; p_property_id: string }
        Returns: Json
      }
      admin_alert_rule_delete: { Args: { p_rule_id: string }; Returns: Json }
      admin_alert_rule_save: { Args: { p_rule: Json }; Returns: Json }
      admin_alert_rules_list: {
        Args: { p_org_id: string; p_property_id?: string }
        Returns: Json
      }
      admin_approval_approvers_list: {
        Args: { p_org_id: string; p_property_id?: string }
        Returns: Json
      }
      admin_approval_rule_delete: { Args: { p_rule_id: string }; Returns: Json }
      admin_approval_rule_save: { Args: { p_rule: Json }; Returns: Json }
      admin_approval_rules_list: {
        Args: { p_org_id: string; p_property_id?: string }
        Returns: Json
      }
      admin_count: { Args: never; Returns: number }
      admin_has_chain_admin_assignment: {
        Args: { p_exclude_assignment_id?: string; p_user_id: string }
        Returns: boolean
      }
      admin_permission_override_set: {
        Args: {
          p_effect: string
          p_permission_code: string
          p_property_id: string
          p_reason: string
          p_user_id: string
          p_valid_to: string
        }
        Returns: Json
      }
      admin_require_not_last_admin: {
        Args: { p_user_id: string }
        Returns: undefined
      }
      admin_role_copy: {
        Args: { p_new_name: string; p_role_id: string }
        Returns: Json
      }
      admin_role_deactivate: { Args: { p_role_id: string }; Returns: Json }
      admin_role_save: { Args: { p_role: Json }; Returns: Json }
      admin_role_set_permissions: {
        Args: { p_permission_codes: string[]; p_role_id: string }
        Returns: Json
      }
      admin_setting_save: {
        Args: {
          p_key: string
          p_org_id: string
          p_property_id: string
          p_value: string
        }
        Returns: Json
      }
      admin_settings_list: {
        Args: { p_org_id: string; p_property_id?: string }
        Returns: Json
      }
      admin_sod_conflict_check: {
        Args: { p_role_id?: string; p_user_id?: string }
        Returns: Json
      }
      admin_sod_pairs: { Args: never; Returns: string[][] }
      admin_user_assign_role: {
        Args: {
          p_outlet_ids?: string[]
          p_property_id?: string
          p_role_id: string
          p_user_id: string
          p_valid_from?: string
          p_valid_to?: string
          p_warehouse_ids?: string[]
        }
        Returns: Json
      }
      admin_user_effective_permissions: {
        Args: { p_property_id: string; p_user_id: string }
        Returns: Json
      }
      admin_user_revoke_role: {
        Args: { p_assignment_id: string; p_reason: string }
        Returns: Json
      }
      admin_user_set_active: {
        Args: { p_active: boolean; p_reason?: string; p_user_id: string }
        Returns: Json
      }
      admin_user_set_pin: {
        Args: { p_pin: string; p_user_id: string }
        Returns: Json
      }
      bootstrap_initial_org: {
        Args: {
          p_admin_one: string
          p_admin_two: string
          p_legal_entity_code: string
          p_legal_entity_name: string
          p_org_name: string
          p_property_code: string
          p_property_name: string
          p_test_user: string
        }
        Returns: Json
      }
      has_perm: {
        Args: { p_perm: string; p_property: string; p_warehouse?: string }
        Returns: boolean
      }
      my_permissions: { Args: { p_property: string }; Returns: string[] }
      my_property_ids: { Args: never; Returns: string[] }
      my_warehouse_ids: { Args: { p_property: string }; Returns: string[] }
      next_doc_no: {
        Args: { p_date?: string; p_doc_type: string; p_entity: string }
        Returns: string
      }
      norm_text: { Args: { p_text: string }; Returns: string }
      require_perm: {
        Args: { p_perm: string; p_property: string; p_warehouse?: string }
        Returns: undefined
      }
      user_has_perm: {
        Args: {
          p_perm: string
          p_property: string
          p_user_id: string
          p_warehouse?: string
        }
        Returns: boolean
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
