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
      accounting_periods: {
        Row: {
          closed_at: string | null
          closed_by: string | null
          created_at: string
          created_by: string | null
          id: string
          legal_entity_id: string
          month: number
          status: string
          updated_at: string
          year: number
        }
        Insert: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id: string
          month: number
          status?: string
          updated_at?: string
          year: number
        }
        Update: {
          closed_at?: string | null
          closed_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id?: string
          month?: number
          status?: string
          updated_at?: string
          year?: number
        }
        Relationships: [
          {
            foreignKeyName: "accounting_periods_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
        ]
      }
      advance_settlement_lines: {
        Row: {
          amount: number
          created_at: string
          gr_id: string | null
          id: string
          org_id: string
          receipt_photo_id: string | null
          settlement_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          gr_id?: string | null
          id?: string
          org_id: string
          receipt_photo_id?: string | null
          settlement_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          gr_id?: string | null
          id?: string
          org_id?: string
          receipt_photo_id?: string | null
          settlement_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "advance_settlement_lines_gr_id_org_id_fkey"
            columns: ["gr_id", "org_id"]
            isOneToOne: false
            referencedRelation: "goods_receipts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "advance_settlement_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "advance_settlement_lines_settlement_id_org_id_fkey"
            columns: ["settlement_id", "org_id"]
            isOneToOne: false
            referencedRelation: "advance_settlements"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      advance_settlements: {
        Row: {
          advance_id: string
          amount: number
          created_at: string
          created_by: string | null
          doc_no: string
          extra_pay_amount: number
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          refund_amount: number
          settled_at: string
          settled_by: string | null
        }
        Insert: {
          advance_id: string
          amount: number
          created_at?: string
          created_by?: string | null
          doc_no: string
          extra_pay_amount?: number
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          refund_amount?: number
          settled_at?: string
          settled_by?: string | null
        }
        Update: {
          advance_id?: string
          amount?: number
          created_at?: string
          created_by?: string | null
          doc_no?: string
          extra_pay_amount?: number
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          refund_amount?: number
          settled_at?: string
          settled_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "advance_settlements_advance_id_fkey"
            columns: ["advance_id"]
            isOneToOne: true
            referencedRelation: "advances"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "advance_settlements_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "advance_settlements_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "advance_settlements_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      advances: {
        Row: {
          amount: number
          created_at: string
          created_by: string | null
          decide_reason: string | null
          decided_at: string | null
          decided_by: string | null
          disbursed_at: string | null
          disbursed_note: string | null
          doc_no: string
          due_settle_at: string | null
          employee_id: string
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          purpose: string
          requested_at: string
          settled_at: string | null
          status: string
          updated_at: string
        }
        Insert: {
          amount: number
          created_at?: string
          created_by?: string | null
          decide_reason?: string | null
          decided_at?: string | null
          decided_by?: string | null
          disbursed_at?: string | null
          disbursed_note?: string | null
          doc_no: string
          due_settle_at?: string | null
          employee_id: string
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          purpose: string
          requested_at?: string
          settled_at?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          amount?: number
          created_at?: string
          created_by?: string | null
          decide_reason?: string | null
          decided_at?: string | null
          decided_by?: string | null
          disbursed_at?: string | null
          disbursed_note?: string | null
          doc_no?: string
          due_settle_at?: string | null
          employee_id?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          purpose?: string
          requested_at?: string
          settled_at?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "advances_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "advances_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "advances_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
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
          severity: string
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
          severity?: string
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
          severity?: string
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
      alerts: {
        Row: {
          ack_at: string | null
          ack_by: string | null
          code: string
          created_at: string
          created_by: string | null
          doc_id: string | null
          doc_type: string | null
          id: string
          org_id: string | null
          payload: Json
          property_id: string | null
          sent_at: string | null
          sent_channels: string[] | null
          severity: string
          title: string
          updated_at: string
        }
        Insert: {
          ack_at?: string | null
          ack_by?: string | null
          code: string
          created_at?: string
          created_by?: string | null
          doc_id?: string | null
          doc_type?: string | null
          id?: string
          org_id?: string | null
          payload?: Json
          property_id?: string | null
          sent_at?: string | null
          sent_channels?: string[] | null
          severity: string
          title: string
          updated_at?: string
        }
        Update: {
          ack_at?: string | null
          ack_by?: string | null
          code?: string
          created_at?: string
          created_by?: string | null
          doc_id?: string | null
          doc_type?: string | null
          id?: string
          org_id?: string | null
          payload?: Json
          property_id?: string | null
          sent_at?: string | null
          sent_channels?: string[] | null
          severity?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "alerts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "alerts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      ap_ledger: {
        Row: {
          amount: number
          created_at: string
          doc_id: string
          doc_type: string
          due_date: string | null
          entry_date: string
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          supplier_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          doc_id: string
          doc_type: string
          due_date?: string | null
          entry_date: string
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          supplier_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          doc_id?: string
          doc_type?: string
          due_date?: string | null
          entry_date?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          supplier_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "ap_ledger_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ap_ledger_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ap_ledger_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ap_ledger_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      approval_delegations: {
        Row: {
          created_at: string
          created_by: string | null
          from_user: string
          id: string
          org_id: string
          property_id: string | null
          reason: string | null
          to_user: string
          updated_at: string
          valid_from: string
          valid_to: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          from_user: string
          id?: string
          org_id: string
          property_id?: string | null
          reason?: string | null
          to_user: string
          updated_at?: string
          valid_from: string
          valid_to: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          from_user?: string
          id?: string
          org_id?: string
          property_id?: string | null
          reason?: string | null
          to_user?: string
          updated_at?: string
          valid_from?: string
          valid_to?: string
        }
        Relationships: [
          {
            foreignKeyName: "approval_delegations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approval_delegations_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
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
      approvals: {
        Row: {
          approver_role_id: string | null
          approver_user_id: string | null
          comment: string | null
          created_at: string
          created_by: string | null
          decided_at: string | null
          decided_by: string | null
          decision: string
          delegated_from: string | null
          doc_id: string
          doc_type: string
          id: string
          org_id: string
          property_id: string
          required_perm: string
          step: number
          updated_at: string
        }
        Insert: {
          approver_role_id?: string | null
          approver_user_id?: string | null
          comment?: string | null
          created_at?: string
          created_by?: string | null
          decided_at?: string | null
          decided_by?: string | null
          decision?: string
          delegated_from?: string | null
          doc_id: string
          doc_type: string
          id?: string
          org_id: string
          property_id: string
          required_perm?: string
          step: number
          updated_at?: string
        }
        Update: {
          approver_role_id?: string | null
          approver_user_id?: string | null
          comment?: string | null
          created_at?: string
          created_by?: string | null
          decided_at?: string | null
          decided_by?: string | null
          decision?: string
          delegated_from?: string | null
          doc_id?: string
          doc_type?: string
          id?: string
          org_id?: string
          property_id?: string
          required_perm?: string
          step?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "approvals_approver_role_id_org_id_fkey"
            columns: ["approver_role_id", "org_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "approvals_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approvals_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "approvals_required_perm_fkey"
            columns: ["required_perm"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["code"]
          },
        ]
      }
      attachments: {
        Row: {
          bucket: string
          created_at: string
          device_info: Json
          device_time: string | null
          doc_id: string
          doc_type: string
          id: string
          legal_entity_id: string
          line_id: string | null
          org_id: string
          path: string
          property_id: string
          reused_from_id: string | null
          sha256: string
          taken_at: string
          updated_at: string
          uploaded_by: string
        }
        Insert: {
          bucket: string
          created_at?: string
          device_info?: Json
          device_time?: string | null
          doc_id: string
          doc_type: string
          id?: string
          legal_entity_id: string
          line_id?: string | null
          org_id: string
          path: string
          property_id: string
          reused_from_id?: string | null
          sha256: string
          taken_at?: string
          updated_at?: string
          uploaded_by?: string
        }
        Update: {
          bucket?: string
          created_at?: string
          device_info?: Json
          device_time?: string | null
          doc_id?: string
          doc_type?: string
          id?: string
          legal_entity_id?: string
          line_id?: string | null
          org_id?: string
          path?: string
          property_id?: string
          reused_from_id?: string | null
          sha256?: string
          taken_at?: string
          updated_at?: string
          uploaded_by?: string
        }
        Relationships: [
          {
            foreignKeyName: "attachments_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attachments_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attachments_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attachments_reused_from_id_fkey"
            columns: ["reused_from_id"]
            isOneToOne: false
            referencedRelation: "attachments"
            referencedColumns: ["id"]
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
      banquet_dishes: {
        Row: {
          banquet_id: string
          created_at: string
          created_by: string | null
          id: string
          note: string | null
          org_id: string
          qty: number
          recipe_id: string
          unit_price: number
          updated_at: string
        }
        Insert: {
          banquet_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          org_id: string
          qty: number
          recipe_id: string
          unit_price: number
          updated_at?: string
        }
        Update: {
          banquet_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          org_id?: string
          qty?: number
          recipe_id?: string
          unit_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "banquet_dishes_banquet_id_org_id_fkey"
            columns: ["banquet_id", "org_id"]
            isOneToOne: false
            referencedRelation: "banquets"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "banquet_dishes_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "banquet_dishes_recipe_id_org_id_fkey"
            columns: ["recipe_id", "org_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      banquet_halls: {
        Row: {
          capacity: number | null
          created_at: string
          created_by: string | null
          id: string
          is_active: boolean
          name: string
          notes: string | null
          org_id: string
          property_id: string
          updated_at: string
        }
        Insert: {
          capacity?: number | null
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name: string
          notes?: string | null
          org_id: string
          property_id: string
          updated_at?: string
        }
        Update: {
          capacity?: number | null
          created_at?: string
          created_by?: string | null
          id?: string
          is_active?: boolean
          name?: string
          notes?: string | null
          org_id?: string
          property_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "banquet_halls_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "banquet_halls_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      banquets: {
        Row: {
          cancel_reason: string | null
          created_at: string
          created_by: string | null
          customer_name: string
          customer_phone: string | null
          deposit_amount: number
          deposit_status: string
          doc_no: string
          end_time: string
          event_date: string
          guests_count: number
          hall: string
          hall_id: string | null
          id: string
          legal_entity_id: string
          notes: string | null
          org_id: string
          property_id: string
          start_time: string
          status: string
          tables_count: number
          updated_at: string
        }
        Insert: {
          cancel_reason?: string | null
          created_at?: string
          created_by?: string | null
          customer_name: string
          customer_phone?: string | null
          deposit_amount?: number
          deposit_status?: string
          doc_no: string
          end_time: string
          event_date: string
          guests_count: number
          hall: string
          hall_id?: string | null
          id?: string
          legal_entity_id: string
          notes?: string | null
          org_id: string
          property_id: string
          start_time: string
          status?: string
          tables_count?: number
          updated_at?: string
        }
        Update: {
          cancel_reason?: string | null
          created_at?: string
          created_by?: string | null
          customer_name?: string
          customer_phone?: string | null
          deposit_amount?: number
          deposit_status?: string
          doc_no?: string
          end_time?: string
          event_date?: string
          guests_count?: number
          hall?: string
          hall_id?: string | null
          id?: string
          legal_entity_id?: string
          notes?: string | null
          org_id?: string
          property_id?: string
          start_time?: string
          status?: string
          tables_count?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "banquets_hall_id_fk"
            columns: ["hall_id", "property_id"]
            isOneToOne: false
            referencedRelation: "banquet_halls"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "banquets_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "banquets_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "banquets_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      buffet_session_dishes: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          note: string | null
          org_id: string
          planned_qty: number
          recipe_id: string
          session_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          org_id: string
          planned_qty: number
          recipe_id: string
          session_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          note?: string | null
          org_id?: string
          planned_qty?: number
          recipe_id?: string
          session_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "buffet_session_dishes_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "buffet_session_dishes_recipe_id_org_id_fkey"
            columns: ["recipe_id", "org_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "buffet_session_dishes_session_id_org_id_fkey"
            columns: ["session_id", "org_id"]
            isOneToOne: false
            referencedRelation: "buffet_sessions"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      buffet_sessions: {
        Row: {
          business_date: string
          cancel_reason: string | null
          created_at: string
          created_by: string | null
          guest_count: number
          id: string
          legal_entity_id: string
          meal: string
          notes: string | null
          org_id: string
          price_per_guest: number | null
          property_id: string
          status: string
          updated_at: string
        }
        Insert: {
          business_date: string
          cancel_reason?: string | null
          created_at?: string
          created_by?: string | null
          guest_count?: number
          id?: string
          legal_entity_id: string
          meal: string
          notes?: string | null
          org_id: string
          price_per_guest?: number | null
          property_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          business_date?: string
          cancel_reason?: string | null
          created_at?: string
          created_by?: string | null
          guest_count?: number
          id?: string
          legal_entity_id?: string
          meal?: string
          notes?: string | null
          org_id?: string
          price_per_guest?: number | null
          property_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "buffet_sessions_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "buffet_sessions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "buffet_sessions_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
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
      count_adjustments: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          count_id: string
          created_at: string
          created_by: string
          id: string
          moves_posted: number
          note: string | null
          org_id: string
          property_id: string
          reject_reason: string | null
          rejected_at: string | null
          rejected_by: string | null
          status: string
          total_value: number
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          count_id: string
          created_at?: string
          created_by?: string
          id?: string
          moves_posted?: number
          note?: string | null
          org_id: string
          property_id: string
          reject_reason?: string | null
          rejected_at?: string | null
          rejected_by?: string | null
          status?: string
          total_value?: number
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          count_id?: string
          created_at?: string
          created_by?: string
          id?: string
          moves_posted?: number
          note?: string | null
          org_id?: string
          property_id?: string
          reject_reason?: string | null
          rejected_at?: string | null
          rejected_by?: string | null
          status?: string
          total_value?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "count_adjustments_count_id_fkey"
            columns: ["count_id"]
            isOneToOne: true
            referencedRelation: "stock_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "count_adjustments_count_id_fkey"
            columns: ["count_id"]
            isOneToOne: true
            referencedRelation: "v_count_result"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "count_adjustments_count_id_fkey"
            columns: ["count_id"]
            isOneToOne: true
            referencedRelation: "v_count_sheet"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "count_adjustments_count_id_org_id_fkey"
            columns: ["count_id", "org_id"]
            isOneToOne: false
            referencedRelation: "stock_counts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "count_adjustments_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "count_adjustments_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "count_adjustments_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      day_locks: {
        Row: {
          business_date: string
          created_at: string
          created_by: string | null
          id: string
          locked_at: string
          locked_by: string
          property_id: string
          shift: string | null
          updated_at: string
          warehouse_id: string
        }
        Insert: {
          business_date: string
          created_at?: string
          created_by?: string | null
          id?: string
          locked_at?: string
          locked_by: string
          property_id: string
          shift?: string | null
          updated_at?: string
          warehouse_id: string
        }
        Update: {
          business_date?: string
          created_at?: string
          created_by?: string | null
          id?: string
          locked_at?: string
          locked_by?: string
          property_id?: string
          shift?: string | null
          updated_at?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "day_locks_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      dish_sales: {
        Row: {
          amount: number
          business_date: string
          created_at: string
          created_by: string | null
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          qty: number
          recipe_id: string | null
          ref_id: string | null
          source: string
          unit_price: number
          updated_at: string
          voided_at: string | null
          voided_by: string | null
        }
        Insert: {
          amount: number
          business_date: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          qty: number
          recipe_id?: string | null
          ref_id?: string | null
          source: string
          unit_price: number
          updated_at?: string
          voided_at?: string | null
          voided_by?: string | null
        }
        Update: {
          amount?: number
          business_date?: string
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          qty?: number
          recipe_id?: string | null
          ref_id?: string | null
          source?: string
          unit_price?: number
          updated_at?: string
          voided_at?: string | null
          voided_by?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "dish_sales_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dish_sales_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dish_sales_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dish_sales_recipe_id_org_id_fkey"
            columns: ["recipe_id", "org_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id", "org_id"]
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
      export_batches: {
        Row: {
          exported_at: string
          exported_by: string
          file_hash: string | null
          id: string
          kind: string
          note: string | null
          org_id: string
          property_id: string
          ref_id: string
          ref_type: string
        }
        Insert: {
          exported_at?: string
          exported_by: string
          file_hash?: string | null
          id?: string
          kind: string
          note?: string | null
          org_id: string
          property_id: string
          ref_id: string
          ref_type: string
        }
        Update: {
          exported_at?: string
          exported_by?: string
          file_hash?: string | null
          id?: string
          kind?: string
          note?: string | null
          org_id?: string
          property_id?: string
          ref_id?: string
          ref_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "export_batches_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "export_batches_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      fifo_allocations: {
        Row: {
          amount: number
          created_at: string
          id: number
          issue_move_id: number
          layer_id: number
          legal_entity_id: string
          org_id: string
          qty: number
          unit_cost: number
        }
        Insert: {
          amount: number
          created_at?: string
          id?: never
          issue_move_id: number
          layer_id: number
          legal_entity_id: string
          org_id: string
          qty: number
          unit_cost: number
        }
        Update: {
          amount?: number
          created_at?: string
          id?: never
          issue_move_id?: number
          layer_id?: number
          legal_entity_id?: string
          org_id?: string
          qty?: number
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "fifo_allocations_issue_move_id_fkey"
            columns: ["issue_move_id"]
            isOneToOne: false
            referencedRelation: "stock_moves"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fifo_allocations_layer_id_fkey"
            columns: ["layer_id"]
            isOneToOne: false
            referencedRelation: "fifo_layers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fifo_allocations_legal_entity_id_org_id_fkey"
            columns: ["legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "fifo_allocations_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      fifo_layers: {
        Row: {
          business_date: string
          created_at: string
          id: number
          item_id: string
          legal_entity_id: string
          org_id: string
          qty_initial: number
          qty_remaining: number
          stock_move_id: number
          unit_cost: number
        }
        Insert: {
          business_date: string
          created_at?: string
          id?: never
          item_id: string
          legal_entity_id: string
          org_id: string
          qty_initial: number
          qty_remaining: number
          stock_move_id: number
          unit_cost: number
        }
        Update: {
          business_date?: string
          created_at?: string
          id?: never
          item_id?: string
          legal_entity_id?: string
          org_id?: string
          qty_initial?: number
          qty_remaining?: number
          stock_move_id?: number
          unit_cost?: number
        }
        Relationships: [
          {
            foreignKeyName: "fifo_layers_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "fifo_layers_legal_entity_id_org_id_fkey"
            columns: ["legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "fifo_layers_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fifo_layers_stock_move_id_fkey"
            columns: ["stock_move_id"]
            isOneToOne: false
            referencedRelation: "stock_moves"
            referencedColumns: ["id"]
          },
        ]
      }
      goods_receipt_lines: {
        Row: {
          accepted_qty_stock: number
          client_uuid: string | null
          created_at: string
          created_by: string | null
          expiry_date: string | null
          gr_id: string
          gross_qty: number
          id: string
          item_id: string
          lot_id: string | null
          lot_no: string | null
          needs_reweigh: boolean
          net_qty: number | null
          net_qty_stock: number
          org_id: string
          over_po_qty_stock: number
          override_by: string | null
          override_reason: string | null
          photo_ids: string[]
          po_line_id: string | null
          posted_warehouse_id: string | null
          property_id: string
          qc_checklist: Json
          qc_status: string
          tare_qty: number
          temperature_c: number | null
          unit_cost: number | null
          uom: string
          updated_at: string
          weigh_count: number
          weigh1_gross_qty: number | null
          weigh1_tare_qty: number | null
          weigh2_gross_qty: number | null
          weigh2_tare_qty: number | null
        }
        Insert: {
          accepted_qty_stock?: number
          client_uuid?: string | null
          created_at?: string
          created_by?: string | null
          expiry_date?: string | null
          gr_id: string
          gross_qty: number
          id?: string
          item_id: string
          lot_id?: string | null
          lot_no?: string | null
          needs_reweigh?: boolean
          net_qty?: number | null
          net_qty_stock: number
          org_id: string
          over_po_qty_stock?: number
          override_by?: string | null
          override_reason?: string | null
          photo_ids?: string[]
          po_line_id?: string | null
          posted_warehouse_id?: string | null
          property_id: string
          qc_checklist?: Json
          qc_status: string
          tare_qty?: number
          temperature_c?: number | null
          unit_cost?: number | null
          uom: string
          updated_at?: string
          weigh_count?: number
          weigh1_gross_qty?: number | null
          weigh1_tare_qty?: number | null
          weigh2_gross_qty?: number | null
          weigh2_tare_qty?: number | null
        }
        Update: {
          accepted_qty_stock?: number
          client_uuid?: string | null
          created_at?: string
          created_by?: string | null
          expiry_date?: string | null
          gr_id?: string
          gross_qty?: number
          id?: string
          item_id?: string
          lot_id?: string | null
          lot_no?: string | null
          needs_reweigh?: boolean
          net_qty?: number | null
          net_qty_stock?: number
          org_id?: string
          over_po_qty_stock?: number
          override_by?: string | null
          override_reason?: string | null
          photo_ids?: string[]
          po_line_id?: string | null
          posted_warehouse_id?: string | null
          property_id?: string
          qc_checklist?: Json
          qc_status?: string
          tare_qty?: number
          temperature_c?: number | null
          unit_cost?: number | null
          uom?: string
          updated_at?: string
          weigh_count?: number
          weigh1_gross_qty?: number | null
          weigh1_tare_qty?: number | null
          weigh2_gross_qty?: number | null
          weigh2_tare_qty?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "goods_receipt_lines_gr_id_org_id_fkey"
            columns: ["gr_id", "org_id"]
            isOneToOne: false
            referencedRelation: "goods_receipts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_po_line_id_org_id_fkey"
            columns: ["po_line_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_order_lines"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_posted_warehouse_id_property_id_fkey"
            columns: ["posted_warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goods_receipt_lines_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      goods_receipts: {
        Row: {
          captured_offline: boolean
          client_uuid: string | null
          created_at: string
          created_by: string | null
          device_time: string
          direct_issue_warehouse_id: string | null
          doc_no: string
          id: string
          legal_entity_id: string
          org_id: string
          photo_review_reason: string | null
          photo_review_status: string
          photo_reviewed_at: string | null
          photo_reviewed_by: string | null
          po_id: string | null
          property_id: string
          received_at: string
          receiver_id: string
          reverse_reason: string | null
          reversed_at: string | null
          reversed_by: string | null
          status: string
          supplier_id: string | null
          total_amount: number
          updated_at: string
          warehouse_id: string
        }
        Insert: {
          captured_offline?: boolean
          client_uuid?: string | null
          created_at?: string
          created_by?: string | null
          device_time?: string
          direct_issue_warehouse_id?: string | null
          doc_no: string
          id?: string
          legal_entity_id: string
          org_id: string
          photo_review_reason?: string | null
          photo_review_status?: string
          photo_reviewed_at?: string | null
          photo_reviewed_by?: string | null
          po_id?: string | null
          property_id: string
          received_at?: string
          receiver_id: string
          reverse_reason?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: string
          supplier_id?: string | null
          total_amount?: number
          updated_at?: string
          warehouse_id: string
        }
        Update: {
          captured_offline?: boolean
          client_uuid?: string | null
          created_at?: string
          created_by?: string | null
          device_time?: string
          direct_issue_warehouse_id?: string | null
          doc_no?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          photo_review_reason?: string | null
          photo_review_status?: string
          photo_reviewed_at?: string | null
          photo_reviewed_by?: string | null
          po_id?: string | null
          property_id?: string
          received_at?: string
          receiver_id?: string
          reverse_reason?: string | null
          reversed_at?: string | null
          reversed_by?: string | null
          status?: string
          supplier_id?: string | null
          total_amount?: number
          updated_at?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "goods_receipts_direct_issue_warehouse_id_property_id_fkey"
            columns: ["direct_issue_warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "goods_receipts_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goods_receipts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goods_receipts_po_id_org_id_fkey"
            columns: ["po_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "goods_receipts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goods_receipts_supplier_id_org_id_fkey"
            columns: ["supplier_id", "org_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "goods_receipts_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      import_batches: {
        Row: {
          committed_at: string | null
          committed_by: string | null
          counts: Json
          created_at: string
          created_by: string | null
          file_name: string
          id: string
          kind: string
          mapping_id: string | null
          org_id: string
          property_id: string
          row_count: number
          status: string
          updated_at: string
        }
        Insert: {
          committed_at?: string | null
          committed_by?: string | null
          counts?: Json
          created_at?: string
          created_by?: string | null
          file_name: string
          id?: string
          kind: string
          mapping_id?: string | null
          org_id: string
          property_id: string
          row_count?: number
          status?: string
          updated_at?: string
        }
        Update: {
          committed_at?: string | null
          committed_by?: string | null
          counts?: Json
          created_at?: string
          created_by?: string | null
          file_name?: string
          id?: string
          kind?: string
          mapping_id?: string | null
          org_id?: string
          property_id?: string
          row_count?: number
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "import_batches_mapping_id_fkey"
            columns: ["mapping_id"]
            isOneToOne: false
            referencedRelation: "import_mappings"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "import_batches_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "import_batches_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      import_mappings: {
        Row: {
          column_map: Json
          created_at: string
          created_by: string | null
          group_map: Json
          id: string
          kind: string
          name: string
          org_id: string
          sample_header: string[] | null
          source: string
          updated_at: string
        }
        Insert: {
          column_map?: Json
          created_at?: string
          created_by?: string | null
          group_map?: Json
          id?: string
          kind: string
          name: string
          org_id: string
          sample_header?: string[] | null
          source?: string
          updated_at?: string
        }
        Update: {
          column_map?: Json
          created_at?: string
          created_by?: string | null
          group_map?: Json
          id?: string
          kind?: string
          name?: string
          org_id?: string
          sample_header?: string[] | null
          source?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "import_mappings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      import_rows: {
        Row: {
          batch_id: string
          created_at: string
          id: string
          issues: Json
          normalized_data: Json
          raw_data: Json
          resolution: Json
          row_no: number
          status: string
          target_code: string | null
          target_id: string | null
          updated_at: string
        }
        Insert: {
          batch_id: string
          created_at?: string
          id?: string
          issues?: Json
          normalized_data?: Json
          raw_data?: Json
          resolution?: Json
          row_no: number
          status?: string
          target_code?: string | null
          target_id?: string | null
          updated_at?: string
        }
        Update: {
          batch_id?: string
          created_at?: string
          id?: string
          issues?: Json
          normalized_data?: Json
          raw_data?: Json
          resolution?: Json
          row_no?: number
          status?: string
          target_code?: string | null
          target_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "import_rows_batch_id_fkey"
            columns: ["batch_id"]
            isOneToOne: false
            referencedRelation: "import_batches"
            referencedColumns: ["id"]
          },
        ]
      }
      item_code_sequences: {
        Row: {
          code_prefix: string
          last_no: number
          org_id: string
        }
        Insert: {
          code_prefix: string
          last_no?: number
          org_id: string
        }
        Update: {
          code_prefix?: string
          last_no?: number
          org_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_code_sequences_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      item_costs: {
        Row: {
          avg_cost: number
          item_id: string
          legal_entity_id: string
          org_id: string
          qty_on_hand: number
          updated_at: string
        }
        Insert: {
          avg_cost?: number
          item_id: string
          legal_entity_id: string
          org_id: string
          qty_on_hand?: number
          updated_at?: string
        }
        Update: {
          avg_cost?: number
          item_id?: string
          legal_entity_id?: string
          org_id?: string
          qty_on_hand?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_costs_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "item_costs_legal_entity_id_org_id_fkey"
            columns: ["legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "item_costs_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
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
          recount_threshold_pct: number | null
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
          recount_threshold_pct?: number | null
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
          recount_threshold_pct?: number | null
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
      lots: {
        Row: {
          created_at: string
          created_by: string | null
          expiry_date: string | null
          id: string
          item_id: string
          lot_no: string
          org_id: string
          property_id: string
          received_at: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          expiry_date?: string | null
          id?: string
          item_id: string
          lot_no: string
          org_id: string
          property_id: string
          received_at?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          expiry_date?: string | null
          id?: string
          item_id?: string
          lot_no?: string
          org_id?: string
          property_id?: string
          received_at?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "lots_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "lots_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "lots_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      minibar_check_lines: {
        Row: {
          amount: number
          check_id: string
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          missing_qty: number
          near_expiry: boolean
          org_id: string
          property_id: string
          unit_price: number
          updated_at: string
        }
        Insert: {
          amount: number
          check_id: string
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          missing_qty: number
          near_expiry?: boolean
          org_id: string
          property_id: string
          unit_price: number
          updated_at?: string
        }
        Update: {
          amount?: number
          check_id?: string
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          missing_qty?: number
          near_expiry?: boolean
          org_id?: string
          property_id?: string
          unit_price?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "minibar_check_lines_check_id_org_id_fkey"
            columns: ["check_id", "org_id"]
            isOneToOne: false
            referencedRelation: "minibar_checks"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "minibar_check_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "minibar_check_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_check_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_check_lines_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      minibar_checks: {
        Row: {
          business_date: string
          charged_at: string | null
          charged_by: string | null
          checked_at: string | null
          checked_by: string | null
          client_uuid: string | null
          created_at: string
          created_by: string | null
          doc_no: string
          folio_no: string | null
          id: string
          is_loss: boolean
          late_note: string | null
          legal_entity_id: string
          org_id: string
          property_id: string
          room_id: string
          status: string
          total_amount: number
          trigger: string
          trolley_shift_id: string | null
          updated_at: string
          waive_approved_by: string | null
          waive_decided_at: string | null
          waive_reason: string | null
          waive_requested_at: string | null
          waive_requested_by: string | null
          write_off_reason: string | null
        }
        Insert: {
          business_date: string
          charged_at?: string | null
          charged_by?: string | null
          checked_at?: string | null
          checked_by?: string | null
          client_uuid?: string | null
          created_at?: string
          created_by?: string | null
          doc_no: string
          folio_no?: string | null
          id?: string
          is_loss?: boolean
          late_note?: string | null
          legal_entity_id: string
          org_id: string
          property_id: string
          room_id: string
          status?: string
          total_amount?: number
          trigger: string
          trolley_shift_id?: string | null
          updated_at?: string
          waive_approved_by?: string | null
          waive_decided_at?: string | null
          waive_reason?: string | null
          waive_requested_at?: string | null
          waive_requested_by?: string | null
          write_off_reason?: string | null
        }
        Update: {
          business_date?: string
          charged_at?: string | null
          charged_by?: string | null
          checked_at?: string | null
          checked_by?: string | null
          client_uuid?: string | null
          created_at?: string
          created_by?: string | null
          doc_no?: string
          folio_no?: string | null
          id?: string
          is_loss?: boolean
          late_note?: string | null
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          room_id?: string
          status?: string
          total_amount?: number
          trigger?: string
          trolley_shift_id?: string | null
          updated_at?: string
          waive_approved_by?: string | null
          waive_decided_at?: string | null
          waive_reason?: string | null
          waive_requested_at?: string | null
          waive_requested_by?: string | null
          write_off_reason?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "minibar_checks_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_checks_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_checks_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_checks_property_id_legal_entity_id_org_id_fkey"
            columns: ["property_id", "legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "legal_entity_id", "org_id"]
          },
          {
            foreignKeyName: "minibar_checks_room_id_property_id_fkey"
            columns: ["room_id", "property_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "minibar_checks_trolley_shift_id_fkey"
            columns: ["trolley_shift_id"]
            isOneToOne: false
            referencedRelation: "trolley_shifts"
            referencedColumns: ["id"]
          },
        ]
      }
      minibar_price_list: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          org_id: string
          price: number
          property_id: string
          updated_at: string
          valid_from: string
          valid_to: string | null
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          org_id: string
          price: number
          property_id: string
          updated_at?: string
          valid_from: string
          valid_to?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          org_id?: string
          price?: number
          property_id?: string
          updated_at?: string
          valid_from?: string
          valid_to?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "minibar_price_list_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "minibar_price_list_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_price_list_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "minibar_price_list_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      no_invoice_listing_lines: {
        Row: {
          amount: number
          created_at: string
          id: string
          item_desc: string
          listing_id: string
          org_id: string
          qty: number
          unit_price: number
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          item_desc: string
          listing_id: string
          org_id: string
          qty: number
          unit_price: number
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          item_desc?: string
          listing_id?: string
          org_id?: string
          qty?: number
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "no_invoice_listing_lines_listing_id_org_id_fkey"
            columns: ["listing_id", "org_id"]
            isOneToOne: false
            referencedRelation: "no_invoice_listings"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "no_invoice_listing_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      no_invoice_listings: {
        Row: {
          created_at: string
          created_by: string | null
          doc_no: string
          gr_id: string | null
          id: string
          legal_entity_id: string
          org_id: string
          po_id: string | null
          property_id: string
          purchase_date: string
          seller_address: string | null
          seller_id_no: string | null
          seller_name: string
          status: string
          total: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          doc_no: string
          gr_id?: string | null
          id?: string
          legal_entity_id: string
          org_id: string
          po_id?: string | null
          property_id: string
          purchase_date: string
          seller_address?: string | null
          seller_id_no?: string | null
          seller_name: string
          status?: string
          total?: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          doc_no?: string
          gr_id?: string | null
          id?: string
          legal_entity_id?: string
          org_id?: string
          po_id?: string | null
          property_id?: string
          purchase_date?: string
          seller_address?: string | null
          seller_id_no?: string | null
          seller_name?: string
          status?: string
          total?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "no_invoice_listings_gr_id_org_id_fkey"
            columns: ["gr_id", "org_id"]
            isOneToOne: false
            referencedRelation: "goods_receipts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "no_invoice_listings_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "no_invoice_listings_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "no_invoice_listings_po_id_org_id_fkey"
            columns: ["po_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "no_invoice_listings_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_deliveries: {
        Row: {
          alert_id: string | null
          attempts: number
          body: string
          channel: string
          created_at: string
          dedupe_key: string
          digest_date: string | null
          error_message: string | null
          id: string
          kind: string
          next_attempt_at: string
          org_id: string
          property_id: string | null
          provider_request_id: number | null
          recipient_address: string
          recipient_user_id: string | null
          sent_at: string | null
          status: string
          title: string
          updated_at: string
        }
        Insert: {
          alert_id?: string | null
          attempts?: number
          body?: string
          channel: string
          created_at?: string
          dedupe_key: string
          digest_date?: string | null
          error_message?: string | null
          id?: string
          kind: string
          next_attempt_at?: string
          org_id: string
          property_id?: string | null
          provider_request_id?: number | null
          recipient_address: string
          recipient_user_id?: string | null
          sent_at?: string | null
          status?: string
          title: string
          updated_at?: string
        }
        Update: {
          alert_id?: string | null
          attempts?: number
          body?: string
          channel?: string
          created_at?: string
          dedupe_key?: string
          digest_date?: string | null
          error_message?: string | null
          id?: string
          kind?: string
          next_attempt_at?: string
          org_id?: string
          property_id?: string | null
          provider_request_id?: number | null
          recipient_address?: string
          recipient_user_id?: string | null
          sent_at?: string | null
          status?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_deliveries_alert_id_fkey"
            columns: ["alert_id"]
            isOneToOne: false
            referencedRelation: "alerts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_deliveries_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_deliveries_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_sender_config: {
        Row: {
          created_at: string
          email_enabled: boolean
          id: string
          org_id: string
          sender_url: string | null
          updated_at: string
          vault_secret_id: string | null
          webpush_enabled: boolean
          zalo_enabled: boolean
        }
        Insert: {
          created_at?: string
          email_enabled?: boolean
          id?: string
          org_id: string
          sender_url?: string | null
          updated_at?: string
          vault_secret_id?: string | null
          webpush_enabled?: boolean
          zalo_enabled?: boolean
        }
        Update: {
          created_at?: string
          email_enabled?: boolean
          id?: string
          org_id?: string
          sender_url?: string | null
          updated_at?: string
          vault_secret_id?: string | null
          webpush_enabled?: boolean
          zalo_enabled?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "notification_sender_config_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: true
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_targets: {
        Row: {
          active: boolean
          address: string | null
          channel: string
          created_at: string
          id: string
          updated_at: string
          user_id: string
        }
        Insert: {
          active?: boolean
          address?: string | null
          channel: string
          created_at?: string
          id?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          active?: boolean
          address?: string | null
          channel?: string
          created_at?: string
          id?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
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
      payment_request_lines: {
        Row: {
          amount: number
          created_at: string
          id: string
          invoice_id: string
          org_id: string
          request_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          invoice_id: string
          org_id: string
          request_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          invoice_id?: string
          org_id?: string
          request_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_request_lines_invoice_id_org_id_fkey"
            columns: ["invoice_id", "org_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "payment_request_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_request_lines_request_id_org_id_fkey"
            columns: ["request_id", "org_id"]
            isOneToOne: false
            referencedRelation: "payment_requests"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      payment_requests: {
        Row: {
          bank_ref: string | null
          created_at: string
          created_by: string | null
          doc_no: string
          due_date: string | null
          export_status: string
          id: string
          legal_entity_id: string
          org_id: string
          paid_at: string | null
          property_id: string
          status: string
          supplier_id: string
          total: number
          updated_at: string
        }
        Insert: {
          bank_ref?: string | null
          created_at?: string
          created_by?: string | null
          doc_no: string
          due_date?: string | null
          export_status?: string
          id?: string
          legal_entity_id: string
          org_id: string
          paid_at?: string | null
          property_id: string
          status?: string
          supplier_id: string
          total: number
          updated_at?: string
        }
        Update: {
          bank_ref?: string | null
          created_at?: string
          created_by?: string | null
          doc_no?: string
          due_date?: string | null
          export_status?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          paid_at?: string | null
          property_id?: string
          status?: string
          supplier_id?: string
          total?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_requests_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_requests_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_requests_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_requests_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
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
      pms_daily_stats: {
        Row: {
          breakfast_pax: number
          business_date: string
          checkouts: number
          created_at: string
          created_by: string
          entered_by: string | null
          extra_beds: number
          guests: number
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          rooms_available: number
          rooms_sold: number
          source: string
          updated_at: string
        }
        Insert: {
          breakfast_pax: number
          business_date: string
          checkouts: number
          created_at?: string
          created_by?: string
          entered_by?: string | null
          extra_beds: number
          guests: number
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          rooms_available: number
          rooms_sold: number
          source?: string
          updated_at?: string
        }
        Update: {
          breakfast_pax?: number
          business_date?: string
          checkouts?: number
          created_at?: string
          created_by?: string
          entered_by?: string | null
          extra_beds?: number
          guests?: number
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          rooms_available?: number
          rooms_sold?: number
          source?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "pms_daily_stats_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pms_daily_stats_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pms_daily_stats_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      pos_import_lines: {
        Row: {
          amount: number
          bill_no: string
          business_date: string
          created_at: string
          id: string
          import_id: string
          item_code: string
          item_name: string | null
          org_id: string
          outlet: string | null
          payment: string | null
          property_id: string
          qty: number
          recipe_id: string | null
          shift: string
          sold_time: string | null
          unit_price: number
        }
        Insert: {
          amount: number
          bill_no: string
          business_date: string
          created_at?: string
          id?: string
          import_id: string
          item_code: string
          item_name?: string | null
          org_id: string
          outlet?: string | null
          payment?: string | null
          property_id: string
          qty: number
          recipe_id?: string | null
          shift: string
          sold_time?: string | null
          unit_price: number
        }
        Update: {
          amount?: number
          bill_no?: string
          business_date?: string
          created_at?: string
          id?: string
          import_id?: string
          item_code?: string
          item_name?: string | null
          org_id?: string
          outlet?: string | null
          payment?: string | null
          property_id?: string
          qty?: number
          recipe_id?: string | null
          shift?: string
          sold_time?: string | null
          unit_price?: number
        }
        Relationships: [
          {
            foreignKeyName: "pos_import_lines_import_id_fkey"
            columns: ["import_id"]
            isOneToOne: false
            referencedRelation: "pos_imports"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_import_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_import_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      pos_imports: {
        Row: {
          business_date: string
          created_at: string
          created_by: string | null
          file_name: string
          file_sha256: string
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          row_count: number
          shift: string
          status: string
          total_amount: number
          unmapped_count: number
          updated_at: string
        }
        Insert: {
          business_date: string
          created_at?: string
          created_by?: string | null
          file_name: string
          file_sha256: string
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          row_count: number
          shift: string
          status?: string
          total_amount: number
          unmapped_count?: number
          updated_at?: string
        }
        Update: {
          business_date?: string
          created_at?: string
          created_by?: string | null
          file_name?: string
          file_sha256?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          row_count?: number
          shift?: string
          status?: string
          total_amount?: number
          unmapped_count?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "pos_imports_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_imports_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "pos_imports_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
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
      purchase_order_lines: {
        Row: {
          ceiling_price: number | null
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          expense_category_id: string | null
          id: string
          item_id: string | null
          org_id: string
          over_ceiling: boolean
          po_id: string
          pr_line_id: string | null
          price_source: string
          qty: number
          qty_stock: number | null
          received_qty_stock: number
          unit_price: number
          uom: string
          updated_at: string
        }
        Insert: {
          ceiling_price?: number | null
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          expense_category_id?: string | null
          id?: string
          item_id?: string | null
          org_id: string
          over_ceiling?: boolean
          po_id: string
          pr_line_id?: string | null
          price_source: string
          qty: number
          qty_stock?: number | null
          received_qty_stock?: number
          unit_price: number
          uom: string
          updated_at?: string
        }
        Update: {
          ceiling_price?: number | null
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          expense_category_id?: string | null
          id?: string
          item_id?: string | null
          org_id?: string
          over_ceiling?: boolean
          po_id?: string
          pr_line_id?: string | null
          price_source?: string
          qty?: number
          qty_stock?: number | null
          received_qty_stock?: number
          unit_price?: number
          uom?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_order_lines_cost_center_id_fkey"
            columns: ["cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_order_lines_expense_category_id_fkey"
            columns: ["expense_category_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_order_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_order_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_order_lines_po_id_org_id_fkey"
            columns: ["po_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_order_lines_pr_line_id_org_id_fkey"
            columns: ["pr_line_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_request_lines"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_order_lines_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      purchase_orders: {
        Row: {
          advance_id: string | null
          channel: string
          created_at: string
          created_by: string | null
          doc_no: string
          estimated_total: number | null
          expected_date: string | null
          export_status: string
          id: string
          kind: string
          legal_entity_id: string
          order_date: string
          org_id: string
          over_ceiling_reason: string | null
          property_id: string
          replaces_po_id: string | null
          service_contract_id: string | null
          status: string
          supplier_id: string | null
          total_amount: number
          updated_at: string
        }
        Insert: {
          advance_id?: string | null
          channel: string
          created_at?: string
          created_by?: string | null
          doc_no: string
          estimated_total?: number | null
          expected_date?: string | null
          export_status?: string
          id?: string
          kind?: string
          legal_entity_id: string
          order_date?: string
          org_id: string
          over_ceiling_reason?: string | null
          property_id: string
          replaces_po_id?: string | null
          service_contract_id?: string | null
          status?: string
          supplier_id?: string | null
          total_amount?: number
          updated_at?: string
        }
        Update: {
          advance_id?: string | null
          channel?: string
          created_at?: string
          created_by?: string | null
          doc_no?: string
          estimated_total?: number | null
          expected_date?: string | null
          export_status?: string
          id?: string
          kind?: string
          legal_entity_id?: string
          order_date?: string
          org_id?: string
          over_ceiling_reason?: string | null
          property_id?: string
          replaces_po_id?: string | null
          service_contract_id?: string | null
          status?: string
          supplier_id?: string | null
          total_amount?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_orders_advance_id_fkey"
            columns: ["advance_id", "org_id"]
            isOneToOne: false
            referencedRelation: "advances"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_orders_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_orders_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_orders_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_orders_replaces_po_id_fkey"
            columns: ["replaces_po_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_orders_service_contract_fk"
            columns: ["service_contract_id", "org_id"]
            isOneToOne: false
            referencedRelation: "service_contracts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_orders_supplier_id_org_id_fkey"
            columns: ["supplier_id", "org_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      purchase_request_lines: {
        Row: {
          converted_qty: number
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          description: string | null
          expense_category_id: string | null
          id: string
          item_id: string | null
          org_id: string
          pr_id: string
          qty: number
          reason: string | null
          uom: string
          updated_at: string
        }
        Insert: {
          converted_qty?: number
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          expense_category_id?: string | null
          id?: string
          item_id?: string | null
          org_id: string
          pr_id: string
          qty: number
          reason?: string | null
          uom: string
          updated_at?: string
        }
        Update: {
          converted_qty?: number
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          description?: string | null
          expense_category_id?: string | null
          id?: string
          item_id?: string | null
          org_id?: string
          pr_id?: string
          qty?: number
          reason?: string | null
          uom?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_request_lines_cost_center_id_fkey"
            columns: ["cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_request_lines_expense_category_id_fkey"
            columns: ["expense_category_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_request_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_request_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_request_lines_pr_id_org_id_fkey"
            columns: ["pr_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_requests"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purchase_request_lines_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      purchase_requests: {
        Row: {
          created_at: string
          created_by: string | null
          doc_no: string
          id: string
          kind: string
          legal_entity_id: string
          need_date: string | null
          note: string | null
          org_id: string
          outlet_id: string | null
          property_id: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          doc_no: string
          id?: string
          kind?: string
          legal_entity_id: string
          need_date?: string | null
          note?: string | null
          org_id: string
          outlet_id?: string | null
          property_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          doc_no?: string
          id?: string
          kind?: string
          legal_entity_id?: string
          need_date?: string | null
          note?: string | null
          org_id?: string
          outlet_id?: string | null
          property_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purchase_requests_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_requests_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purchase_requests_outlet_id_property_id_fkey"
            columns: ["outlet_id", "property_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "purchase_requests_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      purpose_issue_lines: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          lot_id: string | null
          note: string | null
          org_id: string
          property_id: string
          purpose_issue_id: string
          qty: number
          qty_stock: number
          uom: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          lot_id?: string | null
          note?: string | null
          org_id: string
          property_id: string
          purpose_issue_id: string
          qty: number
          qty_stock: number
          uom: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          lot_id?: string | null
          note?: string | null
          org_id?: string
          property_id?: string
          purpose_issue_id?: string
          qty?: number
          qty_stock?: number
          uom?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "purpose_issue_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issue_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purpose_issue_lines_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issue_lines_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "purpose_issue_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issue_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issue_lines_purpose_issue_id_org_id_fkey"
            columns: ["purpose_issue_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purpose_issues"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      purpose_issues: {
        Row: {
          business_date: string
          cost_center_id: string | null
          created_at: string
          created_by: string | null
          doc_no: string
          expense_category_id: string | null
          id: string
          legal_entity_id: string
          note: string | null
          org_id: string
          property_id: string
          purpose_code: string
          status: string
          updated_at: string
          warehouse_id: string
          work_order_id: string | null
        }
        Insert: {
          business_date: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          doc_no: string
          expense_category_id?: string | null
          id?: string
          legal_entity_id: string
          note?: string | null
          org_id: string
          property_id: string
          purpose_code: string
          status?: string
          updated_at?: string
          warehouse_id: string
          work_order_id?: string | null
        }
        Update: {
          business_date?: string
          cost_center_id?: string | null
          created_at?: string
          created_by?: string | null
          doc_no?: string
          expense_category_id?: string | null
          id?: string
          legal_entity_id?: string
          note?: string | null
          org_id?: string
          property_id?: string
          purpose_code?: string
          status?: string
          updated_at?: string
          warehouse_id?: string
          work_order_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "purpose_issues_cost_center_id_fkey"
            columns: ["cost_center_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issues_cost_center_id_org_id_fkey"
            columns: ["cost_center_id", "org_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purpose_issues_expense_category_id_fkey"
            columns: ["expense_category_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issues_expense_category_id_org_id_fkey"
            columns: ["expense_category_id", "org_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "purpose_issues_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issues_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issues_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issues_warehouse_id_fkey"
            columns: ["warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "purpose_issues_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      push_subscriptions: {
        Row: {
          auth: string
          created_at: string
          endpoint: string
          id: string
          last_used_at: string | null
          p256dh: string
          updated_at: string
          user_id: string
        }
        Insert: {
          auth: string
          created_at?: string
          endpoint: string
          id?: string
          last_used_at?: string | null
          p256dh: string
          updated_at?: string
          user_id: string
        }
        Update: {
          auth?: string
          created_at?: string
          endpoint?: string
          id?: string
          last_used_at?: string | null
          p256dh?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      qc_templates: {
        Row: {
          checklist: Json
          created_at: string
          created_by: string | null
          id: string
          item_group_id: string
          org_id: string
          updated_at: string
        }
        Insert: {
          checklist?: Json
          created_at?: string
          created_by?: string | null
          id?: string
          item_group_id: string
          org_id: string
          updated_at?: string
        }
        Update: {
          checklist?: Json
          created_at?: string
          created_by?: string | null
          id?: string
          item_group_id?: string
          org_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "qc_templates_item_group_id_org_id_fkey"
            columns: ["item_group_id", "org_id"]
            isOneToOne: false
            referencedRelation: "item_groups"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "qc_templates_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      recipe_lines: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string | null
          loss_pct: number
          note: string | null
          org_id: string
          qty: number
          sub_recipe_id: string | null
          uom: string
          updated_at: string
          version_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string | null
          loss_pct?: number
          note?: string | null
          org_id: string
          qty: number
          sub_recipe_id?: string | null
          uom: string
          updated_at?: string
          version_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string | null
          loss_pct?: number
          note?: string | null
          org_id?: string
          qty?: number
          sub_recipe_id?: string | null
          uom?: string
          updated_at?: string
          version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recipe_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "recipe_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipe_lines_sub_recipe_id_org_id_fkey"
            columns: ["sub_recipe_id", "org_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "recipe_lines_uom_fkey"
            columns: ["uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "recipe_lines_version_id_org_id_fkey"
            columns: ["version_id", "org_id"]
            isOneToOne: false
            referencedRelation: "recipe_versions"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      recipe_versions: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          recipe_id: string
          status: string
          updated_at: string
          valid_from: string
          version_no: number
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          org_id: string
          recipe_id: string
          status?: string
          updated_at?: string
          valid_from?: string
          version_no: number
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          org_id?: string
          recipe_id?: string
          status?: string
          updated_at?: string
          valid_from?: string
          version_no?: number
        }
        Relationships: [
          {
            foreignKeyName: "recipe_versions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipe_versions_recipe_id_org_id_fkey"
            columns: ["recipe_id", "org_id"]
            isOneToOne: false
            referencedRelation: "recipes"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      recipes: {
        Row: {
          code: string
          created_at: string
          created_by: string | null
          diet_flags: string[]
          group_name: string | null
          id: string
          is_active: boolean
          kind: string
          name: string
          notes: string | null
          org_id: string
          portions_per_batch: number | null
          sale_price: number | null
          updated_at: string
          yield_qty: number | null
          yield_uom: string | null
        }
        Insert: {
          code: string
          created_at?: string
          created_by?: string | null
          diet_flags?: string[]
          group_name?: string | null
          id?: string
          is_active?: boolean
          kind: string
          name: string
          notes?: string | null
          org_id: string
          portions_per_batch?: number | null
          sale_price?: number | null
          updated_at?: string
          yield_qty?: number | null
          yield_uom?: string | null
        }
        Update: {
          code?: string
          created_at?: string
          created_by?: string | null
          diet_flags?: string[]
          group_name?: string | null
          id?: string
          is_active?: boolean
          kind?: string
          name?: string
          notes?: string | null
          org_id?: string
          portions_per_batch?: number | null
          sale_price?: number | null
          updated_at?: string
          yield_qty?: number | null
          yield_uom?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "recipes_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recipes_yield_uom_fkey"
            columns: ["yield_uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
        ]
      }
      report_snapshots: {
        Row: {
          business_date: string
          created_at: string
          created_by: string | null
          data: Json
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          report_code: string
          updated_at: string
        }
        Insert: {
          business_date: string
          created_at?: string
          created_by?: string | null
          data?: Json
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          report_code: string
          updated_at?: string
        }
        Update: {
          business_date?: string
          created_at?: string
          created_by?: string | null
          data?: Json
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          report_code?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "report_snapshots_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_snapshots_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "report_snapshots_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      requisition_lines: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          issued_qty_stock: number
          item_id: string
          lot_id: string | null
          note: string | null
          org_id: string
          property_id: string
          qty: number
          qty_stock: number
          received_qty_stock: number
          requisition_id: string
          uom: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          issued_qty_stock?: number
          item_id: string
          lot_id?: string | null
          note?: string | null
          org_id: string
          property_id: string
          qty: number
          qty_stock: number
          received_qty_stock?: number
          requisition_id: string
          uom: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          issued_qty_stock?: number
          item_id?: string
          lot_id?: string | null
          note?: string | null
          org_id?: string
          property_id?: string
          qty?: number
          qty_stock?: number
          received_qty_stock?: number
          requisition_id?: string
          uom?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "requisition_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisition_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "requisition_lines_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisition_lines_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "requisition_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisition_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisition_lines_requisition_id_org_id_fkey"
            columns: ["requisition_id", "org_id"]
            isOneToOne: false
            referencedRelation: "requisitions"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      requisitions: {
        Row: {
          business_date: string
          created_at: string
          created_by: string | null
          discrepancy_note: string | null
          doc_no: string
          from_warehouse_id: string
          id: string
          legal_entity_id: string
          note: string | null
          org_id: string
          outlet_id: string
          property_id: string
          status: string
          to_warehouse_id: string
          updated_at: string
        }
        Insert: {
          business_date: string
          created_at?: string
          created_by?: string | null
          discrepancy_note?: string | null
          doc_no: string
          from_warehouse_id: string
          id?: string
          legal_entity_id: string
          note?: string | null
          org_id: string
          outlet_id: string
          property_id: string
          status?: string
          to_warehouse_id: string
          updated_at?: string
        }
        Update: {
          business_date?: string
          created_at?: string
          created_by?: string | null
          discrepancy_note?: string | null
          doc_no?: string
          from_warehouse_id?: string
          id?: string
          legal_entity_id?: string
          note?: string | null
          org_id?: string
          outlet_id?: string
          property_id?: string
          status?: string
          to_warehouse_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "requisitions_from_warehouse_id_fkey"
            columns: ["from_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisitions_from_warehouse_id_property_id_fkey"
            columns: ["from_warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "requisitions_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisitions_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisitions_outlet_id_fkey"
            columns: ["outlet_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisitions_outlet_id_property_id_fkey"
            columns: ["outlet_id", "property_id"]
            isOneToOne: false
            referencedRelation: "outlets"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "requisitions_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisitions_to_warehouse_id_fkey"
            columns: ["to_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "requisitions_to_warehouse_id_property_id_fkey"
            columns: ["to_warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
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
      room_setup_standards: {
        Row: {
          clean_type: string
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          org_id: string
          per_guest: boolean
          property_id: string
          qty: number
          room_type_id: string
          updated_at: string
        }
        Insert: {
          clean_type: string
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          org_id: string
          per_guest?: boolean
          property_id: string
          qty: number
          room_type_id: string
          updated_at?: string
        }
        Update: {
          clean_type?: string
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          org_id?: string
          per_guest?: boolean
          property_id?: string
          qty?: number
          room_type_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_setup_standards_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "room_setup_standards_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_setup_standards_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "room_setup_standards_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "room_setup_standards_room_type_id_property_id_fkey"
            columns: ["room_type_id", "property_id"]
            isOneToOne: false
            referencedRelation: "room_types"
            referencedColumns: ["id", "property_id"]
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
      service_acceptances: {
        Row: {
          accepted_at: string
          accepted_by: string | null
          created_at: string
          created_by: string | null
          id: string
          legal_entity_id: string
          note: string | null
          org_id: string
          photo_ids: Json
          po_id: string | null
          property_id: string
          rating: number | null
          schedule_id: string | null
          updated_at: string
        }
        Insert: {
          accepted_at?: string
          accepted_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id: string
          note?: string | null
          org_id: string
          photo_ids?: Json
          po_id?: string | null
          property_id: string
          rating?: number | null
          schedule_id?: string | null
          updated_at?: string
        }
        Update: {
          accepted_at?: string
          accepted_by?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id?: string
          note?: string | null
          org_id?: string
          photo_ids?: Json
          po_id?: string | null
          property_id?: string
          rating?: number | null
          schedule_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_acceptances_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_acceptances_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_acceptances_po_id_org_id_fkey"
            columns: ["po_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "service_acceptances_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_acceptances_schedule_id_org_id_fkey"
            columns: ["schedule_id", "org_id"]
            isOneToOne: false
            referencedRelation: "service_schedules"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      service_contracts: {
        Row: {
          amount_per_cycle: number
          billing_cycle: string
          cost_center_id: string
          created_at: string
          created_by: string | null
          end_date: string | null
          expense_category_id: string
          id: string
          legal_entity_id: string
          org_id: string
          property_id: string
          renew_notice_days: number
          start_date: string
          status: string
          supplier_id: string
          title: string
          updated_at: string
        }
        Insert: {
          amount_per_cycle: number
          billing_cycle: string
          cost_center_id: string
          created_at?: string
          created_by?: string | null
          end_date?: string | null
          expense_category_id: string
          id?: string
          legal_entity_id: string
          org_id: string
          property_id: string
          renew_notice_days?: number
          start_date: string
          status?: string
          supplier_id: string
          title: string
          updated_at?: string
        }
        Update: {
          amount_per_cycle?: number
          billing_cycle?: string
          cost_center_id?: string
          created_at?: string
          created_by?: string | null
          end_date?: string | null
          expense_category_id?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          property_id?: string
          renew_notice_days?: number
          start_date?: string
          status?: string
          supplier_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_contracts_cost_center_id_org_id_fkey"
            columns: ["cost_center_id", "org_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "service_contracts_expense_category_id_org_id_fkey"
            columns: ["expense_category_id", "org_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "service_contracts_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_contracts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_contracts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_contracts_supplier_id_org_id_fkey"
            columns: ["supplier_id", "org_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      service_schedules: {
        Row: {
          contract_id: string
          created_at: string
          created_by: string | null
          due_date: string
          id: string
          legal_entity_id: string
          org_id: string
          period_end: string
          period_start: string
          property_id: string
          status: string
          updated_at: string
        }
        Insert: {
          contract_id: string
          created_at?: string
          created_by?: string | null
          due_date: string
          id?: string
          legal_entity_id: string
          org_id: string
          period_end: string
          period_start: string
          property_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          contract_id?: string
          created_at?: string
          created_by?: string | null
          due_date?: string
          id?: string
          legal_entity_id?: string
          org_id?: string
          period_end?: string
          period_start?: string
          property_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "service_schedules_contract_id_org_id_fkey"
            columns: ["contract_id", "org_id"]
            isOneToOne: false
            referencedRelation: "service_contracts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "service_schedules_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_schedules_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "service_schedules_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
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
      stock_balances: {
        Row: {
          item_id: string
          legal_entity_id: string
          lot_id: string | null
          org_id: string
          property_id: string
          qty: number
          updated_at: string
          warehouse_id: string
        }
        Insert: {
          item_id: string
          legal_entity_id: string
          lot_id?: string | null
          org_id: string
          property_id: string
          qty: number
          updated_at?: string
          warehouse_id: string
        }
        Update: {
          item_id?: string
          legal_entity_id?: string
          lot_id?: string | null
          org_id?: string
          property_id?: string
          qty?: number
          updated_at?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_balances_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "stock_balances_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "stock_balances_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_balances_property_id_legal_entity_id_org_id_fkey"
            columns: ["property_id", "legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "legal_entity_id", "org_id"]
          },
          {
            foreignKeyName: "stock_balances_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      stock_count_lines: {
        Row: {
          book_qty: number | null
          bottle_weight_g: number | null
          client_uuid: string | null
          count_detail: Json
          count_detail_by: string | null
          count_id: string
          counted_by_1: string | null
          counted_by_2: string | null
          counted_qty_1: number | null
          counted_qty_2: number | null
          created_at: string
          explanation: string | null
          final_qty: number | null
          flag: string | null
          id: string
          item_id: string
          org_id: string
          photo_ids: string[]
          reason_code: string | null
          theoretical_qty: number | null
          updated_at: string
          variance_pct: number | null
          variance_qty: number | null
        }
        Insert: {
          book_qty?: number | null
          bottle_weight_g?: number | null
          client_uuid?: string | null
          count_detail?: Json
          count_detail_by?: string | null
          count_id: string
          counted_by_1?: string | null
          counted_by_2?: string | null
          counted_qty_1?: number | null
          counted_qty_2?: number | null
          created_at?: string
          explanation?: string | null
          final_qty?: number | null
          flag?: string | null
          id?: string
          item_id: string
          org_id: string
          photo_ids?: string[]
          reason_code?: string | null
          theoretical_qty?: number | null
          updated_at?: string
          variance_pct?: number | null
          variance_qty?: number | null
        }
        Update: {
          book_qty?: number | null
          bottle_weight_g?: number | null
          client_uuid?: string | null
          count_detail?: Json
          count_detail_by?: string | null
          count_id?: string
          counted_by_1?: string | null
          counted_by_2?: string | null
          counted_qty_1?: number | null
          counted_qty_2?: number | null
          created_at?: string
          explanation?: string | null
          final_qty?: number | null
          flag?: string | null
          id?: string
          item_id?: string
          org_id?: string
          photo_ids?: string[]
          reason_code?: string | null
          theoretical_qty?: number | null
          updated_at?: string
          variance_pct?: number | null
          variance_qty?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_count_lines_count_id_fkey"
            columns: ["count_id"]
            isOneToOne: false
            referencedRelation: "stock_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_count_lines_count_id_fkey"
            columns: ["count_id"]
            isOneToOne: false
            referencedRelation: "v_count_result"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "stock_count_lines_count_id_fkey"
            columns: ["count_id"]
            isOneToOne: false
            referencedRelation: "v_count_sheet"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "stock_count_lines_count_id_org_id_fkey"
            columns: ["count_id", "org_id"]
            isOneToOne: false
            referencedRelation: "stock_counts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "stock_count_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_count_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "stock_count_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      stock_counts: {
        Row: {
          adjusted_at: string | null
          adjusted_by: string | null
          business_date: string
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          client_uuid: string | null
          counter_ids: string[]
          created_at: string
          created_by: string
          doc_no: string
          id: string
          kind: string
          legal_entity_id: string
          locked_at: string | null
          locked_by: string | null
          opened_by: string
          org_id: string
          pos_import_id: string | null
          property_id: string
          shift: string | null
          status: string
          updated_at: string
          warehouse_id: string
        }
        Insert: {
          adjusted_at?: string | null
          adjusted_by?: string | null
          business_date: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          client_uuid?: string | null
          counter_ids?: string[]
          created_at?: string
          created_by?: string
          doc_no: string
          id?: string
          kind: string
          legal_entity_id: string
          locked_at?: string | null
          locked_by?: string | null
          opened_by: string
          org_id: string
          pos_import_id?: string | null
          property_id: string
          shift?: string | null
          status?: string
          updated_at?: string
          warehouse_id: string
        }
        Update: {
          adjusted_at?: string | null
          adjusted_by?: string | null
          business_date?: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          client_uuid?: string | null
          counter_ids?: string[]
          created_at?: string
          created_by?: string
          doc_no?: string
          id?: string
          kind?: string
          legal_entity_id?: string
          locked_at?: string | null
          locked_by?: string | null
          opened_by?: string
          org_id?: string
          pos_import_id?: string | null
          property_id?: string
          shift?: string | null
          status?: string
          updated_at?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_counts_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_counts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_counts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_counts_property_id_legal_entity_id_org_id_fkey"
            columns: ["property_id", "legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "legal_entity_id", "org_id"]
          },
          {
            foreignKeyName: "stock_counts_warehouse_id_fkey"
            columns: ["warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_counts_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      stock_moves: {
        Row: {
          amount: number
          business_date: string
          cost_center_id: string | null
          expense_category_id: string | null
          id: number
          item_id: string
          legal_entity_id: string
          lot_id: string | null
          move_type: string
          org_id: string
          posted_at: string
          posted_by: string
          property_id: string
          purpose_code: string | null
          qty: number
          reverses_move_id: number | null
          source_doc_id: string
          source_doc_type: string
          source_line_id: string | null
          unit_cost: number
          warehouse_id: string
        }
        Insert: {
          amount: number
          business_date: string
          cost_center_id?: string | null
          expense_category_id?: string | null
          id?: never
          item_id: string
          legal_entity_id: string
          lot_id?: string | null
          move_type: string
          org_id: string
          posted_at?: string
          posted_by: string
          property_id: string
          purpose_code?: string | null
          qty: number
          reverses_move_id?: number | null
          source_doc_id: string
          source_doc_type: string
          source_line_id?: string | null
          unit_cost: number
          warehouse_id: string
        }
        Update: {
          amount?: number
          business_date?: string
          cost_center_id?: string | null
          expense_category_id?: string | null
          id?: never
          item_id?: string
          legal_entity_id?: string
          lot_id?: string | null
          move_type?: string
          org_id?: string
          posted_at?: string
          posted_by?: string
          property_id?: string
          purpose_code?: string | null
          qty?: number
          reverses_move_id?: number | null
          source_doc_id?: string
          source_doc_type?: string
          source_line_id?: string | null
          unit_cost?: number
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stock_moves_cost_center_id_org_id_fkey"
            columns: ["cost_center_id", "org_id"]
            isOneToOne: false
            referencedRelation: "cost_centers"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "stock_moves_expense_category_id_org_id_fkey"
            columns: ["expense_category_id", "org_id"]
            isOneToOne: false
            referencedRelation: "expense_categories"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "stock_moves_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "stock_moves_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "stock_moves_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_moves_property_id_legal_entity_id_org_id_fkey"
            columns: ["property_id", "legal_entity_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "legal_entity_id", "org_id"]
          },
          {
            foreignKeyName: "stock_moves_reverses_move_id_fkey"
            columns: ["reverses_move_id"]
            isOneToOne: true
            referencedRelation: "stock_moves"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_moves_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
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
      supplier_invoice_lines: {
        Row: {
          amount: number
          created_at: string
          gr_line_id: string | null
          id: string
          invoice_id: string
          item_id: string | null
          match_result: Json
          org_id: string
          po_line_id: string
          property_id: string
          qty: number
          unit_price: number
          updated_at: string
          vat_amount: number
          vat_rate: number
        }
        Insert: {
          amount: number
          created_at?: string
          gr_line_id?: string | null
          id?: string
          invoice_id: string
          item_id?: string | null
          match_result?: Json
          org_id: string
          po_line_id: string
          property_id: string
          qty: number
          unit_price: number
          updated_at?: string
          vat_amount?: number
          vat_rate?: number
        }
        Update: {
          amount?: number
          created_at?: string
          gr_line_id?: string | null
          id?: string
          invoice_id?: string
          item_id?: string | null
          match_result?: Json
          org_id?: string
          po_line_id?: string
          property_id?: string
          qty?: number
          unit_price?: number
          updated_at?: string
          vat_amount?: number
          vat_rate?: number
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoice_lines_gr_line_id_org_id_fkey"
            columns: ["gr_line_id", "org_id"]
            isOneToOne: false
            referencedRelation: "goods_receipt_lines"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_invoice_lines_invoice_id_org_id_fkey"
            columns: ["invoice_id", "org_id"]
            isOneToOne: false
            referencedRelation: "supplier_invoices"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_invoice_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_invoice_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoice_lines_po_line_id_org_id_fkey"
            columns: ["po_line_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_order_lines"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_invoice_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_invoices: {
        Row: {
          amount_before_tax: number
          created_at: string
          created_by: string | null
          doc_no: string
          id: string
          invoice_date: string
          invoice_no: string
          invoice_symbol: string
          legal_entity_id: string
          lookup_code: string | null
          org_id: string
          property_id: string
          status: string
          supplier_id: string
          total: number
          updated_at: string
          vat_amount: number
          xml_path: string | null
        }
        Insert: {
          amount_before_tax?: number
          created_at?: string
          created_by?: string | null
          doc_no: string
          id?: string
          invoice_date: string
          invoice_no: string
          invoice_symbol: string
          legal_entity_id: string
          lookup_code?: string | null
          org_id: string
          property_id: string
          status?: string
          supplier_id: string
          total?: number
          updated_at?: string
          vat_amount?: number
          xml_path?: string | null
        }
        Update: {
          amount_before_tax?: number
          created_at?: string
          created_by?: string | null
          doc_no?: string
          id?: string
          invoice_date?: string
          invoice_no?: string
          invoice_symbol?: string
          legal_entity_id?: string
          lookup_code?: string | null
          org_id?: string
          property_id?: string
          status?: string
          supplier_id?: string
          total?: number
          updated_at?: string
          vat_amount?: number
          xml_path?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "supplier_invoices_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_invoices_supplier_id_fkey"
            columns: ["supplier_id"]
            isOneToOne: false
            referencedRelation: "suppliers"
            referencedColumns: ["id"]
          },
        ]
      }
      supplier_return_lines: {
        Row: {
          created_at: string
          created_by: string | null
          gr_line_id: string | null
          id: string
          item_id: string
          org_id: string
          photo_ids: string[]
          qty_stock: number
          reason: string | null
          return_id: string
          supplier_signature_path: string | null
          unit_cost: number
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          gr_line_id?: string | null
          id?: string
          item_id: string
          org_id: string
          photo_ids?: string[]
          qty_stock: number
          reason?: string | null
          return_id: string
          supplier_signature_path?: string | null
          unit_cost: number
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          gr_line_id?: string | null
          id?: string
          item_id?: string
          org_id?: string
          photo_ids?: string[]
          qty_stock?: number
          reason?: string | null
          return_id?: string
          supplier_signature_path?: string | null
          unit_cost?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_return_lines_gr_line_id_org_id_fkey"
            columns: ["gr_line_id", "org_id"]
            isOneToOne: false
            referencedRelation: "goods_receipt_lines"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_return_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_return_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_return_lines_return_id_org_id_fkey"
            columns: ["return_id", "org_id"]
            isOneToOne: false
            referencedRelation: "supplier_returns"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      supplier_returns: {
        Row: {
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          confirmed_at: string | null
          confirmed_by: string | null
          created_at: string
          created_by: string | null
          doc_no: string
          gr_id: string | null
          id: string
          legal_entity_id: string
          org_id: string
          photo_ids: string[]
          po_id: string | null
          property_id: string
          reason: string | null
          status: string
          supplier_id: string | null
          supplier_signature_path: string | null
          updated_at: string
        }
        Insert: {
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          created_by?: string | null
          doc_no: string
          gr_id?: string | null
          id?: string
          legal_entity_id: string
          org_id: string
          photo_ids?: string[]
          po_id?: string | null
          property_id: string
          reason?: string | null
          status?: string
          supplier_id?: string | null
          supplier_signature_path?: string | null
          updated_at?: string
        }
        Update: {
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          confirmed_at?: string | null
          confirmed_by?: string | null
          created_at?: string
          created_by?: string | null
          doc_no?: string
          gr_id?: string | null
          id?: string
          legal_entity_id?: string
          org_id?: string
          photo_ids?: string[]
          po_id?: string | null
          property_id?: string
          reason?: string | null
          status?: string
          supplier_id?: string | null
          supplier_signature_path?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "supplier_returns_gr_id_org_id_fkey"
            columns: ["gr_id", "org_id"]
            isOneToOne: false
            referencedRelation: "goods_receipts"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_returns_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_returns_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_returns_po_id_org_id_fkey"
            columns: ["po_id", "org_id"]
            isOneToOne: false
            referencedRelation: "purchase_orders"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "supplier_returns_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "supplier_returns_supplier_id_org_id_fkey"
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
          approved_at: string | null
          approved_by: string | null
          bank_changed_at: string | null
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
          approved_at?: string | null
          approved_by?: string | null
          bank_changed_at?: string | null
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
          approved_at?: string | null
          approved_by?: string | null
          bank_changed_at?: string | null
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
      transfer_lines: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          lot_id: string | null
          note: string | null
          org_id: string
          property_id: string
          qty: number
          qty_stock: number
          received_qty_stock: number
          sent_qty_stock: number
          transfer_id: string
          uom: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          lot_id?: string | null
          note?: string | null
          org_id: string
          property_id: string
          qty: number
          qty_stock: number
          received_qty_stock?: number
          sent_qty_stock?: number
          transfer_id: string
          uom: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          lot_id?: string | null
          note?: string | null
          org_id?: string
          property_id?: string
          qty?: number
          qty_stock?: number
          received_qty_stock?: number
          sent_qty_stock?: number
          transfer_id?: string
          uom?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "transfer_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfer_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "transfer_lines_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfer_lines_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "transfer_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfer_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfer_lines_transfer_id_org_id_fkey"
            columns: ["transfer_id", "org_id"]
            isOneToOne: false
            referencedRelation: "transfers"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      transfers: {
        Row: {
          business_date: string
          created_at: string
          created_by: string | null
          doc_no: string
          from_warehouse_id: string
          id: string
          is_inter_entity: boolean
          legal_entity_id: string
          note: string | null
          org_id: string
          property_id: string
          status: string
          to_warehouse_id: string
          updated_at: string
        }
        Insert: {
          business_date: string
          created_at?: string
          created_by?: string | null
          doc_no: string
          from_warehouse_id: string
          id?: string
          is_inter_entity?: boolean
          legal_entity_id: string
          note?: string | null
          org_id: string
          property_id: string
          status?: string
          to_warehouse_id: string
          updated_at?: string
        }
        Update: {
          business_date?: string
          created_at?: string
          created_by?: string | null
          doc_no?: string
          from_warehouse_id?: string
          id?: string
          is_inter_entity?: boolean
          legal_entity_id?: string
          note?: string | null
          org_id?: string
          property_id?: string
          status?: string
          to_warehouse_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "transfers_from_warehouse_id_fkey"
            columns: ["from_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfers_from_warehouse_id_property_id_fkey"
            columns: ["from_warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
          {
            foreignKeyName: "transfers_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfers_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfers_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfers_to_warehouse_id_fkey"
            columns: ["to_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "transfers_to_warehouse_id_property_id_fkey"
            columns: ["to_warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      trolley_par_levels: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          org_id: string
          par_qty: number
          property_id: string
          trolley_warehouse_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          org_id: string
          par_qty: number
          property_id: string
          trolley_warehouse_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          org_id?: string
          par_qty?: number
          property_id?: string
          trolley_warehouse_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "trolley_par_levels_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "trolley_par_levels_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_par_levels_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_par_levels_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "trolley_par_levels_trolley_warehouse_id_fkey"
            columns: ["trolley_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
        ]
      }
      trolley_shifts: {
        Row: {
          attendant_id: string
          business_date: string
          cancel_reason: string | null
          cancelled_at: string | null
          cancelled_by: string | null
          closed_at: string | null
          closed_by: string | null
          closing_count_id: string | null
          created_at: string
          created_by: string | null
          id: string
          legal_entity_id: string
          opening_count_id: string | null
          org_id: string
          property_id: string
          purpose_issue_id: string | null
          requisition_id: string | null
          rooms_done: Json
          shift: string
          status: string
          trolley_warehouse_id: string
          updated_at: string
        }
        Insert: {
          attendant_id: string
          business_date: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          closed_at?: string | null
          closed_by?: string | null
          closing_count_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id: string
          opening_count_id?: string | null
          org_id: string
          property_id: string
          purpose_issue_id?: string | null
          requisition_id?: string | null
          rooms_done?: Json
          shift?: string
          status?: string
          trolley_warehouse_id: string
          updated_at?: string
        }
        Update: {
          attendant_id?: string
          business_date?: string
          cancel_reason?: string | null
          cancelled_at?: string | null
          cancelled_by?: string | null
          closed_at?: string | null
          closed_by?: string | null
          closing_count_id?: string | null
          created_at?: string
          created_by?: string | null
          id?: string
          legal_entity_id?: string
          opening_count_id?: string | null
          org_id?: string
          property_id?: string
          purpose_issue_id?: string | null
          requisition_id?: string | null
          rooms_done?: Json
          shift?: string
          status?: string
          trolley_warehouse_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "trolley_shifts_closing_count_id_fkey"
            columns: ["closing_count_id"]
            isOneToOne: false
            referencedRelation: "stock_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_closing_count_id_fkey"
            columns: ["closing_count_id"]
            isOneToOne: false
            referencedRelation: "v_count_result"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "trolley_shifts_closing_count_id_fkey"
            columns: ["closing_count_id"]
            isOneToOne: false
            referencedRelation: "v_count_sheet"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "trolley_shifts_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_opening_count_id_fkey"
            columns: ["opening_count_id"]
            isOneToOne: false
            referencedRelation: "stock_counts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_opening_count_id_fkey"
            columns: ["opening_count_id"]
            isOneToOne: false
            referencedRelation: "v_count_result"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "trolley_shifts_opening_count_id_fkey"
            columns: ["opening_count_id"]
            isOneToOne: false
            referencedRelation: "v_count_sheet"
            referencedColumns: ["count_id"]
          },
          {
            foreignKeyName: "trolley_shifts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_property_id_org_id_fkey"
            columns: ["property_id", "org_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "trolley_shifts_purpose_issue_id_fkey"
            columns: ["purpose_issue_id"]
            isOneToOne: false
            referencedRelation: "purpose_issues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_requisition_id_fkey"
            columns: ["requisition_id"]
            isOneToOne: false
            referencedRelation: "requisitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "trolley_shifts_trolley_warehouse_id_fkey"
            columns: ["trolley_warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
        ]
      }
      uom_aliases: {
        Row: {
          alias: string
          created_at: string
          created_by: string | null
          uom_code: string
        }
        Insert: {
          alias: string
          created_at?: string
          created_by?: string | null
          uom_code: string
        }
        Update: {
          alias?: string
          created_at?: string
          created_by?: string | null
          uom_code?: string
        }
        Relationships: [
          {
            foreignKeyName: "uom_aliases_uom_code_fkey"
            columns: ["uom_code"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
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
      waste_report_lines: {
        Row: {
          created_at: string
          created_by: string | null
          id: string
          item_id: string
          lot_id: string | null
          note: string | null
          org_id: string
          property_id: string
          qty_stock: number
          unit_cost: number
          updated_at: string
          waste_report_id: string
        }
        Insert: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id: string
          lot_id?: string | null
          note?: string | null
          org_id: string
          property_id: string
          qty_stock: number
          unit_cost?: number
          updated_at?: string
          waste_report_id: string
        }
        Update: {
          created_at?: string
          created_by?: string | null
          id?: string
          item_id?: string
          lot_id?: string | null
          note?: string | null
          org_id?: string
          property_id?: string
          qty_stock?: number
          unit_cost?: number
          updated_at?: string
          waste_report_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "waste_report_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_report_lines_item_id_org_id_fkey"
            columns: ["item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id", "org_id"]
          },
          {
            foreignKeyName: "waste_report_lines_lot_id_fkey"
            columns: ["lot_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_report_lines_lot_id_property_id_item_id_org_id_fkey"
            columns: ["lot_id", "property_id", "item_id", "org_id"]
            isOneToOne: false
            referencedRelation: "lots"
            referencedColumns: ["id", "property_id", "item_id", "org_id"]
          },
          {
            foreignKeyName: "waste_report_lines_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_report_lines_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_report_lines_waste_report_id_org_id_fkey"
            columns: ["waste_report_id", "org_id"]
            isOneToOne: false
            referencedRelation: "waste_reports"
            referencedColumns: ["id", "org_id"]
          },
        ]
      }
      waste_reports: {
        Row: {
          approved_by: string | null
          business_date: string
          created_at: string
          created_by: string | null
          doc_no: string
          id: string
          legal_entity_id: string
          note: string | null
          org_id: string
          photo_ids: string[]
          property_id: string
          proposed_by: string | null
          reason_code: string
          status: string
          total_value: number
          updated_at: string
          warehouse_id: string
        }
        Insert: {
          approved_by?: string | null
          business_date: string
          created_at?: string
          created_by?: string | null
          doc_no: string
          id?: string
          legal_entity_id: string
          note?: string | null
          org_id: string
          photo_ids?: string[]
          property_id: string
          proposed_by?: string | null
          reason_code: string
          status?: string
          total_value?: number
          updated_at?: string
          warehouse_id: string
        }
        Update: {
          approved_by?: string | null
          business_date?: string
          created_at?: string
          created_by?: string | null
          doc_no?: string
          id?: string
          legal_entity_id?: string
          note?: string | null
          org_id?: string
          photo_ids?: string[]
          property_id?: string
          proposed_by?: string | null
          reason_code?: string
          status?: string
          total_value?: number
          updated_at?: string
          warehouse_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "waste_reports_legal_entity_id_fkey"
            columns: ["legal_entity_id"]
            isOneToOne: false
            referencedRelation: "legal_entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_reports_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_reports_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_reports_warehouse_id_fkey"
            columns: ["warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "waste_reports_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
    }
    Views: {
      mv_report_stock_card_daily: {
        Row: {
          amount: number | null
          business_date: string | null
          item_id: string | null
          lot_id: string | null
          move_count: number | null
          property_id: string | null
          qty: number | null
          warehouse_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stock_moves_warehouse_id_property_id_fkey"
            columns: ["warehouse_id", "property_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id", "property_id"]
          },
        ]
      }
      pg_all_foreign_keys: {
        Row: {
          fk_columns: unknown[] | null
          fk_constraint_name: unknown
          fk_schema_name: unknown
          fk_table_name: unknown
          fk_table_oid: unknown
          is_deferrable: boolean | null
          is_deferred: boolean | null
          match_type: string | null
          on_delete: string | null
          on_update: string | null
          pk_columns: unknown[] | null
          pk_constraint_name: unknown
          pk_index_name: unknown
          pk_schema_name: unknown
          pk_table_name: unknown
          pk_table_oid: unknown
        }
        Relationships: []
      }
      tap_funky: {
        Row: {
          args: string | null
          is_definer: boolean | null
          is_strict: boolean | null
          is_visible: boolean | null
          kind: unknown
          langoid: unknown
          name: unknown
          oid: unknown
          owner: unknown
          returns: string | null
          returns_set: boolean | null
          schema: unknown
          volatility: string | null
        }
        Relationships: []
      }
      v_count_result: {
        Row: {
          book_qty: number | null
          business_date: string | null
          count_detail: Json | null
          count_id: string | null
          count_status: string | null
          counted_qty_1: number | null
          counted_qty_2: number | null
          explanation: string | null
          final_qty: number | null
          flag: string | null
          item_code: string | null
          item_id: string | null
          item_name: string | null
          line_id: string | null
          photo_ids: string[] | null
          reason_code: string | null
          stock_uom: string | null
          theoretical_qty: number | null
          variance_pct: number | null
          variance_qty: number | null
          warehouse_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "items_stock_uom_fkey"
            columns: ["stock_uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "stock_count_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_counts_warehouse_id_fkey"
            columns: ["warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
        ]
      }
      v_count_sheet: {
        Row: {
          business_date: string | null
          count_id: string | null
          count_status: string | null
          explanation: string | null
          final_qty: number | null
          flag: string | null
          has_counted: boolean | null
          item_code: string | null
          item_id: string | null
          item_name: string | null
          line_id: string | null
          my_count_detail: Json | null
          my_counted_qty: number | null
          photo_ids: string[] | null
          reason_code: string | null
          stock_uom: string | null
          warehouse_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "items_stock_uom_fkey"
            columns: ["stock_uom"]
            isOneToOne: false
            referencedRelation: "uoms"
            referencedColumns: ["code"]
          },
          {
            foreignKeyName: "stock_count_lines_item_id_fkey"
            columns: ["item_id"]
            isOneToOne: false
            referencedRelation: "items"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stock_counts_warehouse_id_fkey"
            columns: ["warehouse_id"]
            isOneToOne: false
            referencedRelation: "warehouses"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      _admin_config_require_perm: {
        Args: { p_org_id: string; p_permission: string; p_property_id: string }
        Returns: undefined
      }
      _admin_setting_default: { Args: { p_key: string }; Returns: Json }
      _advance_deadline_hours: {
        Args: { p_org_id: string; p_property_id: string }
        Returns: number
      }
      _advance_has_overdue: {
        Args: { p_employee_id: string }
        Returns: boolean
      }
      _approval_can_decide: {
        Args: { p_approval_id: string; p_property_id: string }
        Returns: boolean
      }
      _build_daily_brief: {
        Args: { p_date: string; p_property_id: string }
        Returns: Json
      }
      _check_price_agreement_overlap: {
        Args: { p_agreement_id: string }
        Returns: undefined
      }
      _check_price_spike: {
        Args: {
          p_business_date: string
          p_doc_id: string
          p_doc_type: string
          p_item_id: string
          p_org_id: string
          p_property_id: string
          p_unit_cost: number
        }
        Returns: undefined
      }
      _cleanup: { Args: never; Returns: boolean }
      _contract_on: { Args: { "": string }; Returns: unknown }
      _count_bottle_qty: {
        Args: { p_bottle_weight_g: number; p_item_id: string }
        Returns: number
      }
      _count_line_threshold_pct: {
        Args: { p_item_id: string; p_org_id: string; p_property_id: string }
        Returns: number
      }
      _count_qty_from_detail: {
        Args: { p_detail: Json; p_item_id: string }
        Returns: number
      }
      _count_recount_threshold_pct: {
        Args: { p_org_id: string; p_property_id: string }
        Returns: number
      }
      _count_user_has_perm: {
        Args: {
          p_perm: string
          p_property: string
          p_user: string
          p_warehouse?: string
        }
        Returns: boolean
      }
      _count_verify_pin: {
        Args: { p_pin: string; p_user: string }
        Returns: undefined
      }
      _count_without_cc_factor: {
        Args: { p_org_id: string; p_property_id: string }
        Returns: number
      }
      _create_alert: {
        Args: {
          p_code: string
          p_doc_id?: string
          p_doc_type?: string
          p_payload?: Json
          p_property_id: string
          p_severity: string
          p_title: string
        }
        Returns: string
      }
      _currtest: { Args: never; Returns: number }
      _db_privs: { Args: never; Returns: unknown[] }
      _decide_approval: {
        Args: {
          p_comment: string
          p_decision: string
          p_doc_id: string
          p_doc_type: string
          p_property_id: string
        }
        Returns: Json
      }
      _export_assert_locked: {
        Args: {
          p_entity_id: string
          p_from: string
          p_property_id: string
          p_scope: string
          p_to: string
        }
        Returns: undefined
      }
      _export_require: {
        Args: { p_from: string; p_legal_entity_id: string; p_to: string }
        Returns: string
      }
      _export_unlocked_dates: {
        Args: {
          p_entity_id: string
          p_from: string
          p_property_id: string
          p_scope: string
          p_to: string
        }
        Returns: string[]
      }
      _extensions: { Args: never; Returns: unknown[] }
      _generate_approval_steps: {
        Args: {
          p_doc_id: string
          p_doc_type: string
          p_org_id: string
          p_property_id: string
          p_total_amount: number
        }
        Returns: number
      }
      _get: { Args: { "": string }; Returns: number }
      _get_latest: { Args: { "": string }; Returns: number[] }
      _get_note: { Args: { "": string }; Returns: string }
      _hk_parse_counts: {
        Args: { p_counts: Json; p_org_id: string }
        Returns: {
          item_id: string
          qty: number
        }[]
      }
      _inventory_avg_cost: {
        Args: { p_entity: string; p_item_id: string }
        Returns: number
      }
      _inventory_transit_wh: {
        Args: { p_property_id: string }
        Returns: string
      }
      _is_verbose: { Args: never; Returns: boolean }
      _minibar_main_wh: { Args: { p_property_id: string }; Returns: string }
      _minibar_price_at: {
        Args: { p_date: string; p_item_id: string; p_property_id: string }
        Returns: number
      }
      _minibar_room_wh: { Args: { p_room_id: string }; Returns: string }
      _notification_chain_digest_recipients: {
        Args: { p_org_id: string }
        Returns: {
          email: string
          has_webpush: boolean
          user_id: string
        }[]
      }
      _notification_deferred_alerts: {
        Args: { p_property_id: string }
        Returns: {
          ack_at: string | null
          ack_by: string | null
          code: string
          created_at: string
          created_by: string | null
          doc_id: string | null
          doc_type: string | null
          id: string
          org_id: string | null
          payload: Json
          property_id: string | null
          sent_at: string | null
          sent_channels: string[] | null
          severity: string
          title: string
          updated_at: string
        }[]
        SetofOptions: {
          from: "*"
          to: "alerts"
          isOneToOne: false
          isSetofReturn: true
        }
      }
      _notification_digest_body: {
        Args: { p_date: string; p_property_id: string; p_snapshot: Json }
        Returns: string
      }
      _notification_digest_recipients: {
        Args: { p_org_id: string; p_property_id: string }
        Returns: {
          email: string
          has_webpush: boolean
          is_chain: boolean
          user_id: string
        }[]
      }
      _notification_flush_group: {
        Args: {
          p_alert_ids: string[]
          p_codes: string[]
          p_now: string
          p_org_id: string
          p_property_id: string
          p_severity: string
          p_times: string[]
          p_titles: string[]
          p_urgent: boolean
        }
        Returns: number
      }
      _notification_http_post: {
        Args: { p_body: Json; p_secret: string; p_url: string }
        Returns: number
      }
      _notification_http_response: {
        Args: { p_request_id: number }
        Returns: {
          error_msg: string
          status_code: number
        }[]
      }
      _notification_is_quiet: { Args: { p_at?: string }; Returns: boolean }
      _notification_mark_alert: {
        Args: { p_alert_id: string; p_channel: string }
        Returns: undefined
      }
      _notification_recipients: {
        Args: { p_code: string; p_org_id: string; p_property_id: string }
        Returns: {
          email: string
          has_webpush: boolean
          user_id: string
        }[]
      }
      _notification_retry_due: { Args: { p_now: string }; Returns: number }
      _notification_rule_for: {
        Args: { p_code: string; p_org_id: string; p_property_id: string }
        Returns: {
          active: boolean
          channels: string[]
          code: string
          created_at: string
          created_by: string | null
          id: string
          org_id: string
          property_id: string | null
          severity: string
          threshold: Json
          updated_at: string
          urgent: boolean
        }
        SetofOptions: {
          from: "*"
          to: "alert_rules"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      _notification_user_email: { Args: { p_user_id: string }; Returns: string }
      _notification_vault_secret: {
        Args: { p_secret_id: string }
        Returns: string
      }
      _pms_daily_stat_int: {
        Args: { p_key: string; p_stats: Json }
        Returns: number
      }
      _po_line_qty_stock: {
        Args: {
          p_item_id: string
          p_org_id: string
          p_qty: number
          p_uom: string
        }
        Returns: number
      }
      _po_resolve_line_price: {
        Args: {
          p_date: string
          p_item_id: string
          p_org_id: string
          p_property_id: string
          p_supplier_id: string
          p_uom: string
        }
        Returns: {
          ceiling_price: number
          over_ceiling: boolean
          price_source: string
          unit_price: number
        }[]
      }
      _post_move: {
        Args: {
          p_cost_center?: string
          p_date: string
          p_doc_id: string
          p_doc_type: string
          p_entity: string
          p_expense_cat?: string
          p_item: string
          p_line_id?: string
          p_lot: string
          p_property: string
          p_purpose?: string
          p_qty: number
          p_reverses?: number
          p_type: string
          p_unit_cost: number
          p_wh: string
        }
        Returns: number
      }
      _prokind: { Args: { p_oid: unknown }; Returns: unknown }
      _query: { Args: { "": string }; Returns: string }
      _receiving_photo_required: {
        Args: { p_item_id: string; p_org_id: string }
        Returns: boolean
      }
      _receiving_po_eligible: {
        Args: { p_channel: string; p_status: string }
        Returns: boolean
      }
      _receiving_quarantine_wh: {
        Args: { p_property_id: string }
        Returns: string
      }
      _receiving_returned_qty: {
        Args: { p_gr_line_id: string }
        Returns: number
      }
      _receiving_tolerance_pct: {
        Args: { p_org_id: string; p_property_id: string }
        Returns: number
      }
      _receiving_unit_cost_stock: {
        Args: {
          p_item_id: string
          p_org_id: string
          p_unit_price: number
          p_uom: string
        }
        Returns: number
      }
      _receiving_update_po_status: {
        Args: { p_po_id: string }
        Returns: undefined
      }
      _refine_vol: { Args: { "": string }; Returns: string }
      _report_advances: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_amenity_cpor: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_ap_aging: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_ap_outstanding: {
        Args: { p_asof: string; p_property_id: string }
        Returns: {
          amount: number
          due_date: string
          supplier_id: string
        }[]
      }
      _report_fnb_revenue: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_minibar: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_open_po_invoice: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_opex: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_receiving_quality: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_rooms_sold: {
        Args: { p_from: string; p_property_id: string; p_to: string }
        Returns: number
      }
      _report_stock_card: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _report_today: { Args: never; Returns: string }
      _report_waste: {
        Args: { p_params: Json; p_property_id: string }
        Returns: Json
      }
      _restaurant_auto_requisition: {
        Args: {
          p_business_date: string
          p_note: string
          p_property_id: string
          p_servings: Json
        }
        Returns: Json
      }
      _restaurant_expand_recipe: {
        Args: { p_recipe_id: string; p_servings: number }
        Returns: {
          item_id: string
          qty: number
          uom: string
        }[]
      }
      _restaurant_foodcost_list: {
        Args: { p_property_id: string }
        Returns: {
          foodcost: number
          has_unknown_cost: boolean
          recipe_id: string
        }[]
      }
      _retval: { Args: { "": string }; Returns: string }
      _rule_enabled: {
        Args: { p_property_id: string; p_rule_code: string }
        Returns: boolean
      }
      _service_po_accepted: {
        Args: { p_date: string; p_po_id: string }
        Returns: boolean
      }
      _setting_get: {
        Args: { p_key: string; p_org_id: string; p_property_id: string }
        Returns: Json
      }
      _sod_check: {
        Args: { p_property_id: string; p_rule_code: string }
        Returns: undefined
      }
      _sod_check_user: {
        Args: { p_property_id: string; p_rule_code: string; p_user_id: string }
        Returns: undefined
      }
      _table_privs: { Args: never; Returns: unknown[] }
      _temptypes: { Args: { "": string }; Returns: string }
      _todo: { Args: never; Returns: string }
      _verify_pin: { Args: { p_pin: string }; Returns: undefined }
      _waste_post_moves: { Args: { p_waste_id: string }; Returns: undefined }
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
      admin_approval_delegation_delete: {
        Args: { p_delegation_id: string; p_org_id: string }
        Returns: Json
      }
      admin_approval_delegation_save: {
        Args: { p_delegation: Json; p_org_id: string }
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
      admin_legal_entity_update: {
        Args: { p_legal_entity_id: string; p_name: string }
        Returns: Json
      }
      admin_org_create: { Args: { p_org: Json }; Returns: Json }
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
      admin_qc_template_delete: {
        Args: { p_template_id: string }
        Returns: Json
      }
      admin_qc_template_save: {
        Args: { p_checklist: Json; p_item_group_id: string; p_org_id: string }
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
      admin_system_health: { Args: never; Returns: Json }
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
      advance_decide: {
        Args: {
          p_advance_id: string
          p_approved: boolean
          p_property_id: string
          p_reason?: string
        }
        Returns: Json
      }
      advance_disburse: {
        Args: { p_advance_id: string; p_note?: string; p_property_id: string }
        Returns: Json
      }
      advance_get: {
        Args: { p_advance_id: string; p_property_id: string }
        Returns: Json
      }
      advance_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      advance_overdue_maintenance: { Args: never; Returns: Json }
      advance_request: {
        Args: { p_amount: number; p_property_id: string; p_purpose: string }
        Returns: Json
      }
      advance_settle: { Args: { p_id: string; p_lines: Json }; Returns: Json }
      alert_ack: { Args: { p_alert_id: string }; Returns: Json }
      approval_decide: {
        Args: {
          p_comment?: string
          p_decision: string
          p_doc_id: string
          p_doc_type: string
          p_property_id: string
        }
        Returns: Json
      }
      approval_timeline: {
        Args: { p_doc_id: string; p_doc_type: string; p_property_id: string }
        Returns: Json
      }
      attachment_list: {
        Args: { p_doc_id: string; p_doc_type: string; p_property_id: string }
        Returns: Json
      }
      attachment_prepare_upload: {
        Args: { p_doc_type: string; p_property_id: string }
        Returns: Json
      }
      attachment_register: {
        Args: {
          p_bucket: string
          p_device_info?: Json
          p_device_time?: string
          p_doc_id: string
          p_doc_type: string
          p_line_id?: string
          p_path: string
          p_property_id: string
          p_sha256: string
        }
        Returns: Json
      }
      banquet_cancel: {
        Args: { p_banquet_id: string; p_property_id: string; p_reason: string }
        Returns: Json
      }
      banquet_complete: {
        Args: { p_banquet_id: string; p_property_id: string }
        Returns: Json
      }
      banquet_confirm: {
        Args: { p_banquet_id: string; p_property_id: string }
        Returns: Json
      }
      banquet_hall_save: {
        Args: { p_hall: Json; p_property_id: string }
        Returns: Json
      }
      banquet_save: {
        Args: { p_banquet: Json; p_property_id: string }
        Returns: Json
      }
      banquet_start: {
        Args: { p_banquet_id: string; p_property_id: string }
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
      buffet_session_cancel: {
        Args: { p_property_id: string; p_reason: string; p_session_id: string }
        Returns: Json
      }
      buffet_session_close: {
        Args: {
          p_guest_count: number
          p_price_per_guest: number
          p_property_id: string
          p_session_id: string
        }
        Returns: Json
      }
      buffet_session_save: {
        Args: { p_property_id: string; p_session: Json }
        Returns: Json
      }
      col_is_null:
        | {
            Args: {
              column_name: unknown
              description?: string
              schema_name: unknown
              table_name: unknown
            }
            Returns: string
          }
        | {
            Args: {
              column_name: unknown
              description?: string
              table_name: unknown
            }
            Returns: string
          }
      col_not_null:
        | {
            Args: {
              column_name: unknown
              description?: string
              schema_name: unknown
              table_name: unknown
            }
            Returns: string
          }
        | {
            Args: {
              column_name: unknown
              description?: string
              table_name: unknown
            }
            Returns: string
          }
      count_add_counter: {
        Args: { p_count_id: string; p_user_id: string }
        Returns: Json
      }
      count_adjust_post: { Args: { p_count_id: string }; Returns: Json }
      count_adjust_reject: {
        Args: { p_count_id: string; p_reason: string }
        Returns: Json
      }
      count_adjust_reverse: {
        Args: { p_count_id: string; p_reason: string }
        Returns: Json
      }
      count_cancel: {
        Args: { p_count_id: string; p_reason: string }
        Returns: Json
      }
      count_list_counters: {
        Args: { p_property_id: string; p_warehouse_id: string }
        Returns: {
          employee_code: string
          full_name: string
          id: string
        }[]
      }
      count_lock: {
        Args: { p_count_id: string; p_reasons?: Json }
        Returns: Json
      }
      count_open: {
        Args: {
          p_business_date: string
          p_client_uuid?: string
          p_counter_ids?: string[]
          p_kind: string
          p_shift?: string
          p_warehouse_id: string
        }
        Returns: Json
      }
      count_record_line: {
        Args: {
          p_bottle_weight_g?: number
          p_client_uuid?: string
          p_count_id: string
          p_detail?: Json
          p_item_id: string
        }
        Returns: Json
      }
      count_submit: {
        Args: { p_count_id: string; p_pins: string[] }
        Returns: Json
      }
      current_ceiling_price: {
        Args: {
          p_date?: string
          p_item_id: string
          p_org_id: string
          p_property_id: string
          p_uom: string
        }
        Returns: number
      }
      day_lock: {
        Args: { p_date: string; p_shift?: string; p_warehouse_id: string }
        Returns: Json
      }
      day_unlock: {
        Args: { p_lock_id: string; p_reason: string }
        Returns: Json
      }
      diag:
        | {
            Args: { msg: unknown }
            Returns: {
              error: true
            } & "Could not choose the best candidate function between: public.diag(msg => text), public.diag(msg => anyelement). Try renaming the parameters or the function itself in the database so function overloading can be resolved"
          }
        | {
            Args: { msg: string }
            Returns: {
              error: true
            } & "Could not choose the best candidate function between: public.diag(msg => text), public.diag(msg => anyelement). Try renaming the parameters or the function itself in the database so function overloading can be resolved"
          }
      diag_test_name: { Args: { "": string }; Returns: string }
      dish_sale_record: {
        Args: {
          p_business_date: string
          p_property_id: string
          p_qty: number
          p_recipe_id: string
          p_unit_price: number
        }
        Returns: Json
      }
      dish_sale_void: {
        Args: { p_property_id: string; p_sale_id: string }
        Returns: Json
      }
      do_tap:
        | { Args: never; Returns: string[] }
        | { Args: { "": string }; Returns: string[] }
      export_advances: {
        Args: { p_from: string; p_legal_entity_id: string; p_to: string }
        Returns: Json
      }
      export_bank_transfer: {
        Args: { p_payment_request_ids: string[] }
        Returns: Json
      }
      export_batch_record: {
        Args: {
          p_file_hash: string
          p_kind: string
          p_note: string
          p_ref_ids: string[]
          p_ref_type: string
        }
        Returns: Json
      }
      export_goods_receipts: {
        Args: { p_from: string; p_legal_entity_id: string; p_to: string }
        Returns: Json
      }
      export_invoices: {
        Args: { p_from: string; p_legal_entity_id: string; p_to: string }
        Returns: Json
      }
      export_payables: {
        Args: { p_from: string; p_legal_entity_id: string; p_to: string }
        Returns: Json
      }
      export_po_data: { Args: { p_po_id: string }; Returns: Json }
      export_stock_issues: {
        Args: { p_from: string; p_legal_entity_id: string; p_to: string }
        Returns: Json
      }
      fail:
        | { Args: never; Returns: string }
        | { Args: { "": string }; Returns: string }
      findfuncs: { Args: { "": string }; Returns: string[] }
      finish: { Args: { exception_on_failure?: boolean }; Returns: string[] }
      format_type_string: { Args: { "": string }; Returns: string }
      has_perm: {
        Args: { p_perm: string; p_property: string; p_warehouse?: string }
        Returns: boolean
      }
      has_unique: { Args: { "": string }; Returns: string }
      import_add_uom_alias: {
        Args: { p_alias: string; p_property_id: string; p_uom_code: string }
        Returns: Json
      }
      import_commit_batch: { Args: { p_batch_id: string }; Returns: Json }
      import_create_batch: {
        Args: {
          p_file_name: string
          p_kind: string
          p_mapping_id: string
          p_property_id: string
          p_rows: Json
        }
        Returns: Json
      }
      import_discard_batch: { Args: { p_batch_id: string }; Returns: Json }
      import_get_batch: { Args: { p_batch_id: string }; Returns: Json }
      import_list_batches: { Args: { p_property_id: string }; Returns: Json }
      import_list_mappings: { Args: { p_property_id: string }; Returns: Json }
      import_normalize_item: {
        Args: {
          p_group_map: Json
          p_org_id: string
          p_raw: Json
          p_resolution: Json
        }
        Returns: Json
      }
      import_normalize_supplier: {
        Args: { p_org_id: string; p_raw: Json; p_resolution: Json }
        Returns: Json
      }
      import_normalize_uom: { Args: { p_raw: string }; Returns: string }
      import_parse_number: { Args: { p_value: Json }; Returns: number }
      import_resolve_row: {
        Args: { p_batch_id: string; p_resolution: Json; p_row_id: string }
        Returns: Json
      }
      import_save_mapping: {
        Args: {
          p_column_map: Json
          p_group_map: Json
          p_kind: string
          p_name: string
          p_property_id: string
        }
        Returns: Json
      }
      import_validate_batch: { Args: { p_batch_id: string }; Returns: Json }
      in_todo: { Args: never; Returns: boolean }
      invoice_approve: { Args: { p_invoice_id: string }; Returns: Json }
      invoice_match: { Args: { p_invoice_id: string }; Returns: Json }
      invoice_save_draft: {
        Args: {
          p_header: Json
          p_lines: Json
          p_property_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      is_empty: { Args: { "": string }; Returns: string }
      isnt_empty: { Args: { "": string }; Returns: string }
      item_create_temp: {
        Args: {
          p_group_id: string
          p_name: string
          p_property_id: string
          p_stock_uom: string
        }
        Returns: Json
      }
      item_merge: {
        Args: { p_from_id: string; p_into_id: string; p_property_id: string }
        Returns: Json
      }
      lives_ok: { Args: { "": string }; Returns: string }
      market_order_create: {
        Args: {
          p_advance_amount: number
          p_expected_date?: string
          p_lines: Json
          p_property_id: string
          p_purpose?: string
        }
        Returns: Json
      }
      minibar_confirm_charge: {
        Args: { p_check_id: string; p_folio_no: string }
        Returns: Json
      }
      minibar_decide_waive: {
        Args: { p_check_id: string; p_decision: string; p_note?: string }
        Returns: Json
      }
      minibar_mark_late_charge: {
        Args: { p_check_id: string; p_note?: string }
        Returns: Json
      }
      minibar_price_set: {
        Args: {
          p_item_id: string
          p_price: number
          p_property_id: string
          p_valid_from: string
          p_valid_to?: string
        }
        Returns: Json
      }
      minibar_recall_list: {
        Args: { p_days?: number; p_property_id: string }
        Returns: Json
      }
      minibar_reconcile: {
        Args: { p_date?: string; p_property_id: string }
        Returns: Json
      }
      minibar_reconcile_all: { Args: never; Returns: Json }
      minibar_refill: {
        Args: { p_lines: Json; p_room_id: string }
        Returns: Json
      }
      minibar_request_check: {
        Args: { p_room_id: string; p_trigger?: string }
        Returns: Json
      }
      minibar_request_waive: {
        Args: { p_check_id: string; p_reason: string }
        Returns: Json
      }
      minibar_submit_check: {
        Args: { p_check_id: string; p_client_uuid?: string; p_lines: Json }
        Returns: Json
      }
      minibar_write_off: {
        Args: { p_check_id: string; p_reason: string }
        Returns: Json
      }
      my_permissions: { Args: { p_property: string }; Returns: string[] }
      my_property_ids: { Args: never; Returns: string[] }
      my_warehouse_ids: { Args: { p_property: string }; Returns: string[] }
      next_doc_no: {
        Args: { p_date?: string; p_doc_type: string; p_entity: string }
        Returns: string
      }
      next_item_code: {
        Args: { p_org_id: string; p_prefix: string }
        Returns: string
      }
      no_invoice_listing_approve: {
        Args: { p_listing_id: string }
        Returns: Json
      }
      no_invoice_listing_save: {
        Args: { p_lines: Json; p_listing: Json; p_property_id: string }
        Returns: Json
      }
      no_plan: { Args: never; Returns: boolean[] }
      norm_text: { Args: { p_text: string }; Returns: string }
      notification_build_daily_all: { Args: never; Returns: Json }
      notification_dispatch_pending: { Args: { p_now?: string }; Returns: Json }
      notification_reconcile_sending: { Args: never; Returns: Json }
      notification_send_digest: {
        Args: { p_business_date?: string; p_property_id: string }
        Returns: Json
      }
      notification_send_digest_all: {
        Args: { p_business_date?: string }
        Returns: Json
      }
      notification_targets_save: {
        Args: { p_active?: boolean; p_address: string; p_channel: string }
        Returns: Json
      }
      notification_worker: { Args: never; Returns: Json }
      num_failed: { Args: never; Returns: number }
      os_name: { Args: never; Returns: string }
      pass:
        | { Args: never; Returns: string }
        | { Args: { "": string }; Returns: string }
      payment_mark_paid: {
        Args: { p_bank_ref: string; p_id: string }
        Returns: Json
      }
      payment_request_create: {
        Args: {
          p_due_date?: string
          p_lines: Json
          p_property_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      payment_request_decide: {
        Args: {
          p_comment?: string
          p_decision: string
          p_property_id: string
          p_request_id: string
        }
        Returns: Json
      }
      period_close: {
        Args: { p_entity_id: string; p_month: number; p_year: number }
        Returns: Json
      }
      period_close_check: {
        Args: { p_entity_id: string; p_month: number; p_year: number }
        Returns: Json
      }
      period_reopen: {
        Args: { p_period_id: string; p_reason: string }
        Returns: Json
      }
      pg_version: { Args: never; Returns: string }
      pg_version_num: { Args: never; Returns: number }
      pgtap_version: { Args: never; Returns: number }
      pms_daily_history: {
        Args: { p_date: string; p_property_id: string }
        Returns: Json
      }
      pms_daily_upsert: {
        Args: { p_date: string; p_property_id: string; p_stats: Json }
        Returns: Json
      }
      po_cancel: {
        Args: { p_po_id: string; p_property_id: string; p_reason: string }
        Returns: Json
      }
      po_close: {
        Args: { p_po_id: string; p_property_id: string; p_reason: string }
        Returns: Json
      }
      po_create_from_pr: {
        Args: {
          p_channel: string
          p_pr_line_ids: string[]
          p_property_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      po_get: {
        Args: { p_po_id: string; p_property_id: string }
        Returns: Json
      }
      po_list: {
        Args: {
          p_channel?: string
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      po_save_draft: {
        Args: { p_po: Json; p_property_id: string }
        Returns: Json
      }
      po_send: {
        Args: { p_po_id: string; p_property_id: string }
        Returns: Json
      }
      po_set_estimated_total: {
        Args: { p_amount: number; p_po_id: string; p_property_id: string }
        Returns: Json
      }
      po_submit: {
        Args: { p_po_id: string; p_property_id: string }
        Returns: Json
      }
      pos_import_commit: {
        Args: {
          p_file_name: string
          p_file_sha256: string
          p_lines: Json
          p_property_id: string
        }
        Returns: Json
      }
      pr_cancel: {
        Args: { p_pr_id: string; p_property_id: string; p_reason: string }
        Returns: Json
      }
      pr_decide: {
        Args: {
          p_comment?: string
          p_decision: string
          p_pr_id: string
          p_property_id: string
        }
        Returns: Json
      }
      pr_get: {
        Args: { p_pr_id: string; p_property_id: string }
        Returns: Json
      }
      pr_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      pr_save_draft: {
        Args: { p_pr: Json; p_property_id: string }
        Returns: Json
      }
      pr_submit: {
        Args: { p_pr_id: string; p_property_id: string }
        Returns: Json
      }
      property_dashboard_overview: {
        Args: { p_property_id: string }
        Returns: Json
      }
      purpose_issue_cancel: {
        Args: { p_issue_id: string; p_property_id: string; p_reason: string }
        Returns: Json
      }
      purpose_issue_get: { Args: { p_issue_id: string }; Returns: Json }
      purpose_issue_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      purpose_issue_post: { Args: { p_issue_id: string }; Returns: Json }
      purpose_issue_reverse: {
        Args: { p_issue_id: string; p_property_id: string; p_reason: string }
        Returns: Json
      }
      purpose_issue_save_draft: { Args: { p_issue: Json }; Returns: Json }
      push_subscribe: {
        Args: { p_auth: string; p_endpoint: string; p_p256dh: string }
        Returns: Json
      }
      push_unsubscribe: { Args: { p_endpoint: string }; Returns: Json }
      receiving_get_photo_review: { Args: { p_gr_id: string }; Returns: Json }
      receiving_get_receipt: { Args: { p_gr_id: string }; Returns: Json }
      receiving_get_task: { Args: { p_po_id: string }; Returns: Json }
      receiving_list_photo_reviews: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_review_status?: string
          p_search?: string
        }
        Returns: Json
      }
      receiving_list_receipts: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      receiving_list_tasks: {
        Args: { p_date?: string; p_property_id: string }
        Returns: Json
      }
      receiving_override_line: {
        Args: { p_gr_line_id: string; p_reason: string }
        Returns: Json
      }
      receiving_post: {
        Args: { p_gr_id: string; p_pin: string }
        Returns: Json
      }
      receiving_record_line: {
        Args: {
          p_client_uuid?: string
          p_expiry?: string
          p_gr_id: string
          p_gross: number
          p_item_id: string
          p_lot?: string
          p_photo_ids?: string[]
          p_po_line_id: string
          p_qc?: Json
          p_tare?: number
          p_uom?: string
        }
        Returns: Json
      }
      receiving_reverse: {
        Args: { p_gr_id: string; p_reason: string }
        Returns: Json
      }
      receiving_review_photos: {
        Args: { p_decision: string; p_gr_id: string; p_reason?: string }
        Returns: Json
      }
      receiving_start: {
        Args: {
          p_client_uuid?: string
          p_direct_issue_wh?: string
          p_po_id: string
          p_warehouse_id: string
        }
        Returns: Json
      }
      recipe_foodcost: {
        Args: { p_property_id: string; p_recipe_id: string }
        Returns: number
      }
      recipe_foodcost_list: {
        Args: { p_property_id: string }
        Returns: {
          foodcost: number
          has_unknown_cost: boolean
          recipe_id: string
        }[]
      }
      recipe_save: {
        Args: { p_property_id: string; p_recipe: Json }
        Returns: Json
      }
      recipe_set_active: {
        Args: {
          p_is_active: boolean
          p_property_id: string
          p_recipe_id: string
        }
        Returns: Json
      }
      report_build_daily: {
        Args: { p_date?: string; p_property_id: string }
        Returns: Json
      }
      report_get: {
        Args: { p_code: string; p_params?: Json; p_property_id: string }
        Returns: Json
      }
      report_refresh_stock_card_mv: { Args: never; Returns: Json }
      require_perm: {
        Args: { p_perm: string; p_property: string; p_warehouse?: string }
        Returns: undefined
      }
      requisition_cancel: {
        Args: {
          p_property_id: string
          p_reason: string
          p_requisition_id: string
        }
        Returns: Json
      }
      requisition_confirm_receipt: {
        Args: {
          p_discrepancy_note?: string
          p_lines: Json
          p_requisition_id: string
        }
        Returns: Json
      }
      requisition_decide: {
        Args: {
          p_comment?: string
          p_decision: string
          p_property_id: string
          p_requisition_id: string
        }
        Returns: Json
      }
      requisition_get: { Args: { p_requisition_id: string }; Returns: Json }
      requisition_issue: {
        Args: { p_lines: Json; p_requisition_id: string }
        Returns: Json
      }
      requisition_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      requisition_save_draft: { Args: { p_requisition: Json }; Returns: Json }
      requisition_submit: {
        Args: { p_property_id: string; p_requisition_id: string }
        Returns: Json
      }
      restaurant_kitchen_today: {
        Args: { p_business_date?: string; p_property_id: string }
        Returns: Json
      }
      restaurant_sales_summary: {
        Args: { p_from?: string; p_property_id: string; p_to?: string }
        Returns: Json
      }
      room_setup_standard_delete: {
        Args: { p_standard_id: string }
        Returns: Json
      }
      room_setup_standard_set: {
        Args: {
          p_clean_type: string
          p_item_id: string
          p_per_guest?: boolean
          p_property_id: string
          p_qty: number
          p_room_type_id: string
        }
        Returns: Json
      }
      runtests:
        | { Args: never; Returns: string[] }
        | { Args: { "": string }; Returns: string[] }
      service_accept: {
        Args: {
          p_note?: string
          p_photos?: Json
          p_po_id?: string
          p_rating?: number
          p_schedule_id?: string
        }
        Returns: Json
      }
      service_accept_reverse: {
        Args: { p_acceptance_id: string; p_reason: string }
        Returns: Json
      }
      service_contract_save: {
        Args: {
          p_contract: Json
          p_contract_id?: string
          p_property_id: string
        }
        Returns: Json
      }
      service_maintenance: { Args: never; Returns: Json }
      service_schedule_generate: { Args: { p_month: string }; Returns: Json }
      skip:
        | { Args: { "": string }; Returns: string }
        | { Args: { how_many: number; why: string }; Returns: string }
      supplier_approve: {
        Args: {
          p_approved: boolean
          p_property_id: string
          p_reason?: string
          p_supplier_id: string
        }
        Returns: Json
      }
      supplier_assessment_warnings: {
        Args: { p_supplier_id: string }
        Returns: Json
      }
      supplier_bank_approve: {
        Args: {
          p_approved: boolean
          p_bank_account_id: string
          p_property_id: string
          p_reason?: string
        }
        Returns: Json
      }
      supplier_bank_request: {
        Args: {
          p_account_name: string
          p_account_no: string
          p_bank_name: string
          p_property_id: string
          p_supplier_id: string
        }
        Returns: Json
      }
      supplier_return_cancel: {
        Args: { p_reason: string; p_return_id: string }
        Returns: Json
      }
      supplier_return_confirm: {
        Args: {
          p_photo_ids?: string[]
          p_return_id: string
          p_supplier_signature_path?: string
        }
        Returns: Json
      }
      supplier_return_eligible_lines: {
        Args: { p_gr_id: string }
        Returns: Json
      }
      supplier_return_get: { Args: { p_return_id: string }; Returns: Json }
      supplier_return_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      supplier_return_post: {
        Args: { p_gr_id: string; p_lines: Json }
        Returns: Json
      }
      supplier_set_status: {
        Args: {
          p_property_id: string
          p_reason: string
          p_status: string
          p_supplier_id: string
        }
        Returns: Json
      }
      supplier_submit: {
        Args: { p_property_id: string; p_supplier_id: string }
        Returns: Json
      }
      temp_code_maintenance: { Args: never; Returns: Json }
      temp_item_is_expired: { Args: { p_item_id: string }; Returns: boolean }
      throws_ok: { Args: { "": string }; Returns: string }
      todo:
        | { Args: { how_many: number }; Returns: boolean[] }
        | { Args: { how_many: number; why: string }; Returns: boolean[] }
        | { Args: { why: string }; Returns: boolean[] }
        | { Args: { how_many: number; why: string }; Returns: boolean[] }
      todo_end: { Args: never; Returns: boolean[] }
      todo_start:
        | { Args: never; Returns: boolean[] }
        | { Args: { "": string }; Returns: boolean[] }
      transfer_cancel: {
        Args: { p_property_id: string; p_reason: string; p_transfer_id: string }
        Returns: Json
      }
      transfer_get: { Args: { p_transfer_id: string }; Returns: Json }
      transfer_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      transfer_receive: {
        Args: { p_lines: Json; p_transfer_id: string }
        Returns: Json
      }
      transfer_save_draft: { Args: { p_transfer: Json }; Returns: Json }
      transfer_send: {
        Args: { p_lines: Json; p_transfer_id: string }
        Returns: Json
      }
      trolley_par_set: {
        Args: {
          p_item_id: string
          p_par_qty: number
          p_property_id: string
          p_trolley_warehouse_id: string
        }
        Returns: Json
      }
      trolley_shift_cancel: {
        Args: { p_reason: string; p_shift_id: string }
        Returns: Json
      }
      trolley_shift_close: {
        Args: { p_counts: Json; p_rooms_done?: Json; p_shift_id: string }
        Returns: Json
      }
      trolley_shift_get: { Args: { p_shift_id: string }; Returns: Json }
      trolley_shift_open: {
        Args: {
          p_business_date?: string
          p_counts: Json
          p_property_id: string
          p_shift?: string
          p_trolley_wh: string
        }
        Returns: Json
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
      waste_cancel: {
        Args: { p_property_id: string; p_reason: string; p_waste_id: string }
        Returns: Json
      }
      waste_decide: {
        Args: {
          p_comment?: string
          p_decision: string
          p_property_id: string
          p_waste_id: string
        }
        Returns: Json
      }
      waste_get: { Args: { p_waste_id: string }; Returns: Json }
      waste_list: {
        Args: {
          p_limit?: number
          p_offset?: number
          p_property_id: string
          p_search?: string
          p_status?: string
        }
        Returns: Json
      }
      waste_save_draft: { Args: { p_waste: Json }; Returns: Json }
      waste_submit: {
        Args: { p_property_id: string; p_waste_id: string }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      _time_trial_type: {
        a_time: number | null
      }
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
